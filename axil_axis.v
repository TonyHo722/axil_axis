// AXIL-AXIS (AA module) - AXILite-AXIS Protcol Conversion
//  Specification: https://github.com/bol-edu/fsic_fpga/blob/main/fsic-spec-dev/modules/FSIC-AXIS%20interface%20specification.md
//
// The code is based on axil_axis.sv by Zack, and make the following modification
// - Simplify the design, no fifo
//   Assuming there is no pipeline ss->lm transaction
//   Assuming there is no pipeline ls->sm tranaction
//
// - Support
//   Axis-slave to Axilite Master (ss->lm) read/write
//   Axilite slave to Axis-master (ls -> sm) read/write
//   mailbox - support on 2 x DW register (DW#0 - FSIC, DW#1 - FPGA)
//



module AXIL_AXIS #( parameter pADDR_WIDTH   = 12,
                    parameter pDATA_WIDTH   = 32
                  )
(

// Clock & Reset - only use axis_clk, axis_rst_n
  input  wire          axi_clk,
  input  wire          axi_reset_n,
  input  wire          axis_clk,
  input  wire          axis_rst_n

// LM AW Channel
  output wire          m_awvalid,
  output wire  [31: 0] m_awaddr,
  input  wire          m_awready,

// LM  W Channel
  output wire          m_wvalid,
  output wire  [31: 0] m_wdata,
  output wire   [3: 0] m_wstrb,    // always asserted - 32-bit write
  input  wire          m_wready,

/// LM AR Channel
  output wire          m_arvalid,
  output wire  [31: 0] m_araddr,
  input  wire          m_arready,

// LM R Channel
  output wire          m_rready,
  input  wire          m_rvalid,
  input  wire  [31: 0] m_rdata,

// LS AW Channel
  output wire          s_awready,
  input  wire          s_awvalid,
  input  wire  [14: 0] s_awaddr,

// LS W Channel
  output wire          s_wready,
  input  wire          s_wvalid,
  input  wire  [31: 0] s_wdata,
  input  wire   [3: 0] s_wstrb,

// LS AR Channel
  output wire          s_arready,
  input  wire          s_arvalid,
  input  wire  [14: 0] s_araddr,

// LS R Channel
  output wire  [31: 0] s_rdata,
  output wire          s_rvalid,
  input  wire          s_rready,


// -- Stream Interface with Axi-Switch (AS)

// SS
  input  wire  [31: 0] as_aa_tdata,
  input  wire   [3: 0] as_aa_tstrb,
  input  wire   [3: 0] as_aa_tkeep,
  input  wire          as_aa_tlast,
  input  wire          as_aa_tvalid,
  input  wire   [1: 0] as_aa_tuser,
  output  wire         aa_as_tready,

// Sm
  output wire  [31: 0] aa_as_tdata,
  output wire   [3: 0] aa_as_tstrb,
  output wire   [3: 0] aa_as_tkeep,
  output wire          aa_as_tlast,
  output wire          aa_as_tvalid,
  output wire   [1: 0] aa_as_tuser,
  input  wire          as_aa_tready,

// Misc
  input  wire          cc_aa_enable,   // all Axilite Slave transaction should be qualified by cc_aa_enable
  output wire          mb_irq          // Generate interrupt only when mailbox write by remote, i.e. from Axi-stream

);


//
//   SS Cycle type - decode from tuser, refer to fsic-axis specification
//   tuser = 2'b00    - axis cycle, ignored, we don't handle pure axi-stream transaction
//   tuser = 2'b01      - axilite write - 2T  T1:address, T2:data
//   tuser = 2'b10      - axilite read - address
//   tuser = 2'b11      - axilite read - data response
// Note: we should use latched tuser ----
wire ss_axis_cyc    = (r_ss_tuser = 2'b00);    // actually, we won't receive this cycle, as should filter it out
wire ss_wr_cyc      = (r_ss_tuser = 2'b01);    // tready is return as long as address/data latch is ok (ss_w_addr_data_ok)
wire ss_rd_cyc      = (r_ss_tuser = 2'b10);    // tready is return as long as ss_rw_addr latch is ok
wire ss_rs_cyc      = (r_ss_tuser = 2'b11);
wire ls_read_resp   = ss_axil_read_data_cyc;                   // it is used to terminate ls_read
wire ss_axil_cyc    = ss_axil_write_cycle | ss_axil_read_addr_cyc;


// --------------------------------
// Internal States
// --------------------------------
// Data/Address latches
// As a slave, we will latch (save) address and data used for the master transaction later, example
// SS -> LM  write : latch address (1st T) and data (2nd T)
// SS -> LM  read :  latch address (1st T)
// LS -> SS  write : latch address (@awvalid), data (@wvalid)
// LS -> SS  read : latch address (@arvalid), data @(rready)
//

// ----------------------------
// cycle tracking
// ----------------------------
// ------  SS -> LM  -----------
reg r_ss_wr;                  // status: latched ss transaction is read(0) or write(1)
wire r_ss_rd = ~r_ss_wr;
reg r_ss_cyc;                 // indicate there is ss_cyc pending, set by ss, reset by axil transaction complete
wire r_lm_ready;               // axil master transaction complete, m_wready (write), m_rvalid(read)
wire r_lm_done = r_lm_ready;    // same as lm_ready
// reg r_ss_rresp;               // ss read data is complete, generate sm response data ??

// LS -> SM
reg r_ls_wr;                // latched ls transaction is read(0), write(1)
reg r_ls_cyc;               // ls cycle is ongoing
                            //   write -> until sm send out stream write
                            //   read  -> until ss receive tuser= 2'b11, read response data
reg r_sm_done;              // sm write transferred, or sm read address sent
// reg r_ss_axil_rresp;        // r_ss  ??

// ----------------------------------
//  Lached Input address / data from SS, LS, LM (response data)
// ----------------------------------
// --- SS ------------
reg [31:0] r_ss_rw_addr;      // ss-axil address latch for read and write - shared
reg [31:0] r_ss_w_data;
// reg [31:0] r_ss_rs_data;      // ss data for tuser = 2'b11, used as ls respond data, i.e. s_rdata
wire [31:0] r_ss_rs_data = r_ss_w_data;  // shared, guarantee exclusive ss w/rs by not responding ss_ready, the code may be confusing
reg [1:0] r_tuser;

// ls side latched address, data, or read data to send
reg [31:0] r_ls_rw_addr;
reg [31:0] r_ls_w_data;
reg [3:0]  r_ls_w_wstrb;

// lm side - latch read response data
reg [31:0] r_lm_rs_data;    // lm read response data

// ---------------------------------
// Output Addrss/Data to LM, SM from internal latched registers
// ---------------------------------
// ----  LM - Adddress/Data
assign m_awaddr = r_ss_rw_addr;
assign m_araddr = r_ss_rm_addr;
assign m_wdata  = r_ss_w_data;

// ----- LS - Data Source
// 1. SS RS data  - r_ss_rs_data
// 2. ls_aa_internal data
assign s_rdata  = ls_aa_internal ?  ls_aa_internal_data            // TBD
                                 : r_ss_rs_data;

// ---- SM - data has several sources
// 1. LS write - 1st T = r_ls_rw_addr
//               2nd T = r_ls_w_data
// 2. LM RS  : r_lm_rs_data
//
assign aa_as_tdata = 32'bx;         // TBD


// ---------------------------------------
// Output: control signals
// ---------------------------------------
// ------ LM -----
assign m_awvalid =

// ------- LS ------
assign s_awready = ~r_ls_cyc;       // if there is pending LS cycle, don't return s_awready
assign s_wready  = ~r_ls_cyc;       // same as s_awready
assign s_arready = ~r_ls_cyc;
assign s_rvalid  = r_ls_cyc & (  aa_internal        // if aa internal return immediate
                               | (ss)



reg r_sm_wr_cyc;                // ls_write -> sm write
reg r_sm_rd_cyc                 // ls_read -> sm read


// ---------------------------------------
// Mailbox
// - Memory-mapped address (32'h3000_3000~3000_3xxx)
// - We support only 2 * DW register
//   DW[0] @ Caravel side
//   DW[1] @ FPGA side
//   Axis_Axilite (32'h3000_2000~32'h3000_2xxx)
//   Mailbox (32'h3000_3000~32'h3000_3xxx)
//   We only need to compare Addr[15:12] = 'h2, or 'h3
// ---------------------------------------
parameter MBOX_BASE_  32'h
reg [31:0] mb_regs[1:0];    // only support 2*DW to save space


// ---------------------------------------
// AA-register
// - Memory-mapped Address (32'h3000_2000 ~'h3000_2xxx) - cc_aa_enable
    //--------------------------------------------------
    // for AA_REG description
    // offset 0-3 (32bit):
    //   bit 0: Enable Interrupt
    //       0 = disable interrupt signal
    //       1 = enable interrupt signal
    // offset 4-7 (32bit):
    //   bit 0: Interrupt Status
    //       0: interrupt has occurred
    //       0: no interrupt
    //--------------------------------------------------
reg intr_enable;  // rw: offset:0, bit0  - use addr[2] to select
reg intr_status;  // ro: offset:4, bit0

//
// aa_internal - address hit internal aa configuration or mailbox
// either from ss, or ls
//
wire ss_aa_internal = { r_ss_rw_addr[11:8] == 3'b001 );   // xxxx_3xxx, xxxx_2xxx only compare addr[11:8];
wire ls_aa_internal = { r_ls_rw_addr[11:8] == 3'b001 ) & cc_aa_enable;
/// wire [31:0] ss_aa_internal_data;        // ss won't read aa internal data
wire [31:0] ls_aa_internal_data = r_ls_rw_addr[8] ? (r_ls_rw_addr[2] ? mb_regs[1]           // 'h3000_3004  mbox[1]
                                                                     : mb_regs[0] )         // 'h3000_3000  mbox[0]
                                                  : (r_ls_rw_addr[2] ? {31'b0, intr_status}         // 'h3000_2004  aa_reg[4-7]
                                                                     : {31'b0, intr_intr_enable} )   // 'h3000_2000  aa_reg[3-0]
                                                  ;



// --------------------------------------
// SS, SM, LS, LM output generation
// --------------------------------------
// AxiL AW  :  m_awvalid, m_awaddr
// Axil W   :  m_wvalid, m_wdata, m_wstrb
// Axil AR  :  m_arvalid, m_araddr
// Axil R   :  m_rready;
//
//
// LM output
reg         r_awvalid;
reg         r_wvalid;
reg         r_arvalid;

assign  m_awvalid   = r_awvalid;
assign  m_awaddr    = {4'b0000, r_ss_rw_addr[27:0]};
assign  m_wvalid    = r_wvalid;
assign  m_wdata     = r_ss_w_data;
assign  m_wstrb     = r_ss_rw_addr[31:28];
assign  m_arvalid   = r_arvalid;
assign  m_araddr    = r_ss_rw_addr;
assign  m_rready    = 1'b1;             // axilite master read can always accept data

// LS output

// SM output
// Axi-stream Master
//   output wire  [31: 0] aa_as_tdata,
  output wire   [3: 0] aa_as_tstrb,
  output wire   [3: 0] aa_as_tkeep,
  output wire          aa_as_tlast,
  output wire          aa_as_tvalid,
  output wire   [1: 0] aa_as_tuser,
  input  wire          as_aa_tready

// LS ouput




//
// -- Protocol Conversiion Waveform
// SS (W) -> LM (W)
// clk      |   |   |   |   |   |   |   |   |   |
// tvalid   _/-----------
// tdata    _<AAAAAA><DDD>
// tready   _____/-------\_______________________
// en       ______/-------\______________________
// --- LM AW/W Channel
// awvalid/wvalid   _____/----------------------
// awdata/awaddr---------<AD---->
// awready  _________________/--\______________
// wready   _____________________/--\__________
//
//  Note: tready only asserts if latch is free, e.g. ss_w_addr_data_ok
//
// Receive SS W Address
// note: as long as ss_w_addr_data_ok asserted, we can asserts tready
// Receiving ss_w_addr, and ss_w_data is two steps processes addr -> data
// use a flag to indicate it is first step or 2nd step
//  ！ss_w_flag & aa_as_tvalid  -> 1st T
//  ss_w_flag & aa_as_tvalid -> 2nd T

// some of the interface signal can simply wired to internal state registers
// aa_as_tready if tuser = 2'b01 - write, as long as ss_w_addr_data_ok, i.e. address & data latch is free, we can asserts
assign aa_as_tready = !r_ss_cyc;   // if r_ss_cyc = 1, there is pending ss->axil, the address/data latch is occupied

reg ss_w_flag；  // toggle 0->1->0, use it to generate ss_rw_addr, ss_w_data latch enable
always @(posedge axis_clk or negedge axis_rst_n) begin   // asynchronous reset
    if( !axis_rst_n ) begin
        ss_w_flag <= 0;
    end else begin
        if(  aa_as_tready & ss_axil_write_cyc & !ss_w_flag ) begin
            ss_w_flag <= 1;
        end else begin
            ss_w_flag <= 0;
        end
    end
end

//
// r_ss_rw_addr, r_ss_wdata
//  - ss side address/data latch
// Note: it does not need reset, why ? when it is used, the content will be valid anyway
//
always @( posedge axis_clk ) begin
    if( ss_axil_cyc & ss_as_tready ) begin
        if( !ss_w_flag ) begin
            r_ss_rw_addr <= ss_as_tdata;
        end else begin
            r_ss_w_data <= ss_as_tdata;
        end
    end
end

//
// r_ss_cyc  - there is pending ss->axil cycle pending, r_ss_rw_addr, r_ss_w_data is not free
// it is set when ss_axil_
// reset when axil cycle complete  - r_lm_ready m_wready (write), m_rvalid(read)
//
always @( posedge axis_clk or negedge axis_rst_n) begin
    if( !axis_rst_n) begin
        r_ss_cyc <= 0;
    end else begin
        if( ss_axil_cyc & ss_as_tready) begin
            r_ss_cyc <= 1;
        end else if(  r_lm_ready ) begin
            r_ss_cyc <= 0;
        end
    end
end

//
// r_ss_rw - a status indicate the pending ss-axil is write (1) or read(0)
// it is a status, when used, it must be qualified by command, thus, it does not need reset
// it can be unknow (X) before the first ss-axil cycle, it is dont-care anyway
//
always @( posedge axis_clk) begin
    if( ss_axil_cyc) r_ss_rw = ss_axil_write_cyc;
end

//
// r_ss_rdata
//
reg [31:0] r_ss_resp_data;    // ss data for tuser = 2'b11, i.e. ls read response data from ss

always @( posedge axis_clk ) begin
    if( ss_axil_read_data_cyc) r_ls_r_data <= ss_as_tdata;
end

// ---------------------------------------
// Start Axil master transaction
// ---------------------------------------
// Axil master write - triggered by r_ss_cyc & r_ss_wr
//  AW, W channel will assert awvalid, wvalid at the same timing
//  reset to wready -> AW and
// Note: if address hit Mailbox or AA internal register -> does not generate Axil master cycle
// -- awvalid
always @( posedge axis_clk or negedge axis_rst_n) begin
    if( !axis_rst_n) begin
        r_awvalid <= 0;
    end else begin
        if( r_ss_cyc & r_ss_wr & !r_awvalid & !ss_aa_internal) begin      // set valid, when there is pending r_ss_cyc & r_ss_wr
            r_awvalid <= 1;                             // note: r_ss_cyc is a level signal, see it only when r_awvalid = 0
        end else if( m_awready ) begin                  // reset when sample m_awready
            r_awvalid <= 0;
        end
    end
end
// -- wvalid
always @( posedge axis_clk or negedge axis_rst_n) begin
    if( !axis_rst_n) begin
        r_wvalid <= 0;
    end else begin
        if( r_ss_cyc & r_ss_wr & !r_wvalid & !ss_aa_internal) begin      // set valid, when there is pending r_ss_cyc & r_ss_wr
            r_wvalid <= 1;                             // note: r_ss_cyc is a level signal, see it only when r_awvalid = 0
        end else if( m_wready ) begin                  // reset when sample m_wready
            r_wvalid <= 0;
        end
    end
end


//
// axil master read - ar triggered by r_ss_cyc & !r_ss_wr
// response rvalid -> should trigger sm tuser=1'b11  read response
//
//  -- arvalid
always @( posedge axis_clk or negedge axis_rst_n) begin
    if( !axis_rst_n) begin
        r_arvalid <= 0;
    end else begin
        if( r_ss_cyc & !r_ss_wr & !r_arvalid & !ss_aa_internal) begin      // set valid, when there is pending r_ss_cyc & r_ss_wr
            r_arvalid <= 1;                             // note: r_ss_cyc is a level signal, see it only when r_awvalid = 0
        end else if( m_arready ) begin                  // reset when sample m_wready
            r_arvalid <= 0;
        end
    end
end

// TBD
// Mailbox or AA register read/write from SS
// combine from SS, and LS
//

//
// axil read response  -
// -- rvalid - is used to latch into r_
// -- m_rready is always asserted
//
// -- r_ss_rresp, r_ss_rdata
always @(posedge axis_clk or negedge axis_rst_n) begin
    if( !axis_rst_n ) begin
        r_ss_rresp <= 0;
    end else begin
        if( r_ss_cyc & !r_ss_wr & m_rvalid & !r_ss_rresp ) begin
            r_ss_rresp <= 1;
            r_ss_rdata <= m_rdata;          // latch the read data
        end else begin
            r_ss_rresp <= 0;
        end
    end
end


// -----------------------------------------
// Axilite-Slave  - ls
//  Write: latch address and data -> pass to sm
//  Read:
//     - latch read address -> pass to sm
//     - ss response, generate LS read response
//       assume the AR, and R can not be interrupted
// -----------------------------------------

//
// LS-write - latch address / data used for SM
//
// Axilite Slave AW Channel

// -- r_ls_rw_addr  - s_awvalid or s_arvalid
always @( posedge axis_clk) begin
    if( cc_aa_enable & ((s_awvalid & s_awready) | (s_arvalid & s_arready)) begin
        r_ls_rw_addr <= {17'b0, s_awaddr};           // what address should be passed to the other end?
    end
end

// -- r_ls_w_wstrb
always @( posedge axis_clk) begin
    if( cc_aa_enable & s_awvalid & s_awready ) begin
        r_ls_w_data <= s_wdata;
        r_ls_w_wstrb <= s_wstrb;
    end
end

// r_ls_wr
always @( posedge axis_clk) begin
    if( cc_aa_enable & (s_awvalid & s_awready)) begin
        r_ls_wr <= 1;
    end else if( c_aa_enable & (s_arvalid & s_arready) begin
        r_ls_wr <= 0;
    end else begin
        r_ls_wr <= 0;
    end
end

// r_ls_cyc  - asserts from s_awvalid or s_arvalid to r_sm_done
always @( posedge axis_clk or negedge axis_rst_n) begin
    if( !axis_rst_n ) begin
        r_ls_cyc <= 1'b0;
    end else if( (s_awvalid | s_arvalid) & !r_ls_cyc ) begin
        r_ls_cyc <= 1'b1;
    end else if( r_sm_done ) begin
        r_ls_cyc <= 0;
    end
end

//
// LS Read  -
//  AR:  latch r_ls_rw_addr, it is already done in LS write
//  R:  need to get data from SS - tuser = 2'b11
//     source of read data
//      1. mailbox
//      2. aa_reg
//      3. ss_read_resp
//
wire [31:0] mbox_read =
wire [31:0] aa_reg = {31'b0, }


// -----------------------------------------
// Stream-master cycle - SN transaction
// Trigger by r_ls_cyc & !ls_aa_internal
// note: write to mailbox will send to SM
// -----------------------------------------
reg r_sm_done;          // indicate sm transaction complete






// ss_w_addr_data_ok is reset to 1
// set to 0 when ss_axil_write_cycle or ss_axil_read_addr_cycle
// set to 1 when correponding axilite master cycle complete
// Note: there is no pipeline


endmodule // AXIL_AXIS
