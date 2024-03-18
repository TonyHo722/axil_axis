// AXIL-AXIS (AA module) - AXILite-AXIS Protcol Conversion
//  Specification: https://github.com/bol-edu/fsic_fpga/blob/main/fsic-spec-dev/modules/FSIC-AXIS%20interface%20specification.md
// 
// - Simplify the design, no fifo
//   Assuming there is no pipeline ss->lm transaction
//   Assuming there is no pipeline ls->sm tranaction 
//   Assuming there is no concurrent ss, ls transaction, i.e. either ss, or ls transaction is only, it will stall the other.
// 
// - Support 
//   Axis-slave to Axilite Master (ss->lm -> sm) read/write 
//   Axilite slave to Axis-master (ls -> sm -> ss) read/write
//   mailbox - support on 8 DW register (DW#0 - FSIC, DW#1 - FPGA)
// 



module AXIL_AXIS #( parameter pADDR_WIDTH   = 12,
                    parameter pDATA_WIDTH   = 32
                  )
(

// Clock & Reset - only use axis_clk, axis_rst_n
  input  wire          axi_clk,
  input  wire          axi_reset_n,
  input  wire          axis_clk,
  input  wire          axis_rst_n,

// LM - Axilite Master
// LM AW Channel
  output wire          m_awvalid,
  output wire  [31: 0] m_awaddr,
  input  wire          m_awready,

// LM  W Channel
  output wire          m_wvalid,
  output wire  [31: 0] m_wdata,
  output wire   [3: 0] m_wstrb,    // follow axis 2nd cycle ss_tdata[31:28]
  input  wire          m_wready,

/// LM AR Channel
  output wire          m_arvalid,
  output wire  [31: 0] m_araddr,
  input  wire          m_arready,

// LM R Channel
  output wire          m_rready,
  input  wire          m_rvalid,
  input  wire  [31: 0] m_rdata,


// LS - Axilite Slave
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

// SS - Stream Slave
  input  wire  [31: 0] as_aa_tdata,
  input  wire   [3: 0] as_aa_tstrb,
  input  wire   [3: 0] as_aa_tkeep,
  input  wire          as_aa_tlast,
  input  wire          as_aa_tvalid,
  input  wire   [1: 0] as_aa_tuser,
  output  wire         aa_as_tready,

// SM - Stream Master
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

// naming rule
// r_   : registered/latched
// _n   : active low
// _cyc : transaction cycle 
// interface ports:
// - ss (stream slave)
// - sm (stream master)
// - ls (axilite slave)
// - lm (axilite master)
// cycle type indicators:
// - wr : write transaction
// - rd : read transaction
// - rs : read response

// aa_reset_n - AA module reset, active low
// 1. system reset
// 2. cc_aa_enable = 0 : if AA is not enable, treated as reset
wire aa_reset_n = axis_rst_n;

wire ss_t2;
//
//   SS Cycle type - decode from tuser, refer to fsic-axis specification
//   tuser = 2'b00    - axis cycle, ignored, we don't handle pure axi-stream transaction
//   tuser = 2'b01    - axilite write - 2T  T1:address, T2:data
//   tuser = 2'b10    - axilite read - address
//   tuser = 2'b11    - axilite read - data response
// Note: we should use latched tuser ----
wire ss_axis_cyc    = (as_aa_tuser == 2'b00);    // actually, we won't receive this cycle, as should filter it out
wire ss_wr_cyc      = (as_aa_tuser == 2'b01);    // tready is return as long as address/data latch is ok (ss_w_addr_data_ok)
wire ss_rd_cyc      = (as_aa_tuser == 2'b10);    // tready is return as long as ss_rw_addr latch is ok
wire ss_rs_cyc      = (as_aa_tuser == 2'b11); 


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
// cycle tracking  - r_ss_cyc, r_ls_cyc
// ----------------------------
// ------  SS -> LM  -----------
//reg  r_ss_wr;                  // status: latched ss transaction is read(0) or write(1)
//wire r_ss_rd = ~r_ss_wr;
//reg  r_ss_cyc;                 // indicate there is ss_cyc pending, set by ss, reset by axil transaction complete
wire r_ss_cyc;
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
reg [31:0] r_ss_rw_addr;            // ss-axil address latch for read and write - shared
reg [31:0] r_ss_wdata;             // ss-axil data latch for write, 
                                    //    also used for ss-axil read response data, guarantee exclusive ss w/rs by not responding ss_ready
                                    //    if r_ss_cyc is on-going, don't asserts ss_tready
reg [3:0]  r_ss_wstrb;               // ss-axil wstb latch - from SS 1T tdata[31:28]
reg [1:0]  r_tuser;                 // tuser is encoded with cycle type            


// reg [31:0] r_ss_rs_data;         // ss data for tuser = 2'b11, used as ls respond data, i.e. s_rdata
wire [31:0] r_ss_rs_data = r_ss_wdata;  // shared, guarantee exclusive ss w/rs by not responding ss_ready, the code may be confusing


// ---  LS -----------  Axilite Slave
// ls side latched address, data, or read data to send
reg [31:0] r_ls_rw_addr;            // ls address
reg [31:0] r_ls_wdata;              // ls write data
reg [3:0]  r_ls_wstrb;            // ls wstrb

// --- LM  ------------ Axilite Master
// lm side - latch read response data
reg [31:0] r_lm_rs_data;            // lm read response data 


// ----------------------------------
//  Module Interface signals - Address/Data to LM, SM from internal latched registers
// ---------------------------------


// ----  LM - Adddress/Data   - from SS latched address/data
assign m_awaddr = r_ss_rw_addr;
assign m_araddr = r_ss_rw_addr;
assign m_wdata  = r_ss_wdata;
assign m_wstrb  = r_ss_wstrb;

// 
// aa_internal - address hit internal aa configuration or mailbox
// From SS
// AA  'h3000_2xxx   r_ss_rw_addr[27:0]
// aa_reg (internal) a[27:0] = 28'h000_21xx
// aa_mbox           a[27:0] = 28'h000_20xx
// From LS
// use r_ls_rw_addr[11:0]
//    aa_reg   12'h1xx
//    aa_mbox  12'h0xx
// 
// From LS
//   - read ( AA, MBOX), Write AA   => no need trigger LS state machine
// From SS
//   - write/read AA  => no need to trigger SS state machine
//   - write Mbox
wire ss_aa_reg  = ( r_ss_rw_addr[27:8] == 20'h000_21 );   // xxxx_3xxx, xxxx_2xxx only compare addr[11:8];
wire ss_aa_mbox = ( r_ss_rw_addr[27:8] == 20'h000_20 );  
wire ls_aa_reg  = ( r_ls_rw_addr[11:8] == 4'h1 );
wire ls_aa_mbox = ( r_ls_rw_addr[11:8] == 4'h0 );


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
    //       1: interrupt has occurred
    //       0: no interrupt
    //--------------------------------------------------
reg intr_enable;  // rw: offset:0, bit0  - use addr[2] to select
reg intr_status;  // ro: offset:4, bit0

// ---------------------------------------
// Mailbox 
// - Memory-mapped address (32'h3000_2000~3000_201f)
//   Use address[4:2]  to index mb_regs
// ---------------------------------------
// parameter MBOX_BASE_  
reg [31:0] mb_regs[7:0];    // only support 8*DW to save space


/// wire [31:0] ss_aa_internal_data;        // ss won't read aa internal data
wire [31:0] ls_aa_internal_data = ls_aa_reg ? (r_ss_rw_addr[2] ? {31'b0, intr_status}
                                                               : {31'b0, intr_enable})                                             
                                            : mb_regs[r_ls_rw_addr[4:2]];


// for SS read 
wire [31:0] sm_aa_internal_data = ss_aa_reg ? (r_ss_rw_addr[2] ? {31'b0, intr_status}
                                                                : {31'b0, intr_enable})
                                            : mb_regs[r_ss_rw_addr[4:2]];



// ----- LS - Data Source
// 1. SS RS data  - r_ss_rs_data 
// 2. ls_aa_internal data
// TBD: ls_aa_internal_data
// TBD: ls_aa_internal 
assign s_rdata  = (ls_aa_reg | ls_aa_mbox) ? ls_aa_internal_data            // TBD: 
                                 : r_ss_rs_data;        // from SS read-response tuser=11

// ---- SM - data has several sources
// 1. LS write - 1st T = r_ls_rw_addr
//               2nd T = r_ls_wdata
// 2. SS read response  : r_lm_rs_data
// 
assign aa_as_tdata =  ({32{sm_wr_t1}}  & r_ls_rw_addr)     // LS->SM
                   |  ({32{sm_wr_t2}}  & r_ls_wdata ) 
                   |  ({32{r_ss_cyc & !ss_aa_reg}} & r_lm_rs_data )  // SS read
                   |  ({32{r_ss_cyc  &  ss_aa_reg}} & sm_aa_internal_data) 
                   ;





// ----------------------------
// mb_regs, intr_status, inter_enalbe
// LS write - s_wready qualify by ls_aa_reg, ls_aa_mbx
// SS write - ss_t2 @ clk  qualify by ss_aa_reg ls_aa_mbox
reg r_ss_t2;   // one cycle after ss_t2 to ensure ss address/data is valid
always @(posedge axis_clk or negedge axis_rst_n) begin
    if(! axis_rst_n)  begin
        r_ss_t2 <= 0;
    end else begin
        r_ss_t2 <= ss_t2;
    end
end

// 
// intr_status
//  set by ss write to mbox
//  reset by ls write to status with 1  (write one to clear)
// 
always @(posedge axis_clk or negedge axis_rst_n) begin
    if( !axis_rst_n ) begin
        intr_status <= 0;
    end else begin

        // intr_staus
        if(s_wready & ls_aa_reg & r_ls_rw_addr[2] & r_ls_wdata[0]) 
            intr_status <= 1'b0;    // write-one-to clear 
        else if( r_ss_t2  & ss_aa_mbox ) 
            intr_status <= 1'b1;    // mbox write set status

    end
end 

always @(posedge axis_clk or negedge axis_rst_n) begin
    if( !axis_rst_n ) begin
        intr_status <= 0;
        intr_enable <= 0;
    end else begin

        // intr_enable
        if(s_wready & ls_aa_reg & !r_ls_rw_addr[2] ) 
            intr_enable <= r_ls_wdata[0];
        else if( r_ss_t2  & ss_aa_reg & !r_ss_rw_addr[2] ) 
            intr_enable  <= r_ss_wdata[0];
        else 
            intr_enable <= intr_enable ;

        // mbox
        if(s_wready & ls_aa_mbox) 
            mb_regs[r_ls_rw_addr[4:2]] <= r_ls_wdata;
        else if( r_ss_t2  & ss_aa_mbox ) 
            mb_regs[r_ss_rw_addr[4:2]] <= r_ss_wdata;
    end
end

// --- mb_irq ---
// asserts mb_irq when  intr_status = 1 & intr_enable
//
assign mb_irq = intr_status & intr_enable; 

// -------------------------------------------------------
// LS State Machine - Tracking LS -> SM Conversion
// Note： LS State machine & SS State machine can not run currently
//  LS read AA reg + MBOX LS_RD -> LS_DONE
//  LS write AA_reg       LS_WR -> LS_DONE
//  LS write AA_MBOX   pass to FPGA -> LS_WR_SM1
// -------------------------------------------------------
reg [4:0] ls_sm_fsm;

//
// sm fsm state encoding is used to generate related control signal
//                         {r_ls_cyc, r_ls_wr, r_sm_cyc, w1/w2 or ss_read, done}
`define LS_IDLE             5'b0_0_0_0_0              
`define LS_RD               5'b1_0_0_0_0
`define LS_WR               5'b1_1_0_0_0
`define LS_WR_SM1           5'b1_1_1_0_0
`define LS_WR_SM2           5'b1_1_1_1_0
`define LS_RD_SM_REQ        5'b1_0_1_1_0
`define LS_RD_SS_WAIT_RS    5'b1_0_1_0_0
`define LS_DONE             5'b1_0_0_0_1

// cycle indicator and control signal generaion
assign r_ls_cyc = ls_sm_fsm[4];
wire   r_ls_only_cyc = ls_sm_fsm[4] & !ls_sm_fsm[2];  // LS_RD, LS_WR
assign r_ls_wr  = ls_sm_fsm[3];
assign r_ls_sm_cyc = ls_sm_fsm[2];
assign sm_wr_t1 = (ls_sm_fsm == `LS_WR_SM1);
assign sm_wr_t2 = (ls_sm_fsm == `LS_WR_SM2);
assign ls_done  = ls_sm_fsm[0];

// interface signals  - axilite slave
assign s_awready = r_ls_cyc & r_ls_wr & ls_done;
assign s_wready  = s_awready;
assign s_arready  = (ls_sm_fsm == `LS_RD);
assign s_rvalid = r_ls_cyc & !r_ls_wr & ls_done;

// control signals
// {ls_sm_enable, ls_sm_wr, sm_ready, sm_rs_ready}
// Note: LS, SS State machine is exclusive 
wire ls_sm_enable = !r_ss_cyc & cc_aa_enable & ((s_awvalid & s_wvalid) | s_arvalid);   // axilite AW & W AR request asserts
wire ls_sm_wr = s_awvalid;                  // axilite AW - write transaction
wire sm_ready = as_aa_tready;               // sm bus ready if write 2 cycle
wire ss_rs_ready = as_aa_tvalid & ss_rs_cyc; // axis slave receives read completion
wire ls_ready  = ls_sm_wr ? ls_done : ls_done & s_rready;      // ls read need to wait s_rreay

// State Machine - ls_sm_fsm
always @(posedge axis_clk or negedge axis_rst_n) begin   // asynchronous reset
    if( !axis_rst_n ) begin
        ls_sm_fsm = `LS_IDLE;
    end else begin
        case(ls_sm_fsm) 
            `LS_IDLE : 
                if(ls_sm_enable) begin
                    if(ls_sm_wr) ls_sm_fsm <= `LS_WR;
                    else         ls_sm_fsm <= `LS_RD;
                end else begin
                                ls_sm_fsm <= `LS_IDLE;
                end
            `LS_WR:  
                if(ls_aa_reg)   ls_sm_fsm <= `LS_DONE;
                else            ls_sm_fsm <= `LS_WR_SM1;
            `LS_WR_SM1: 
                if(sm_ready)    ls_sm_fsm <= `LS_WR_SM2;
                else            ls_sm_fsm <= `LS_WR_SM1;
            `LS_WR_SM2:
                if(sm_ready)    ls_sm_fsm <= `LS_DONE;
                else            ls_sm_fsm <= `LS_WR_SM2;
            `LS_RD:             
                if( ls_aa_reg | ls_aa_mbox ) ls_sm_fsm <= `LS_DONE;
                else                         ls_sm_fsm <= `LS_RD_SM_REQ;
            `LS_RD_SM_REQ:                  // send 1T read request
                if(sm_ready)    ls_sm_fsm <= `LS_RD_SS_WAIT_RS;
                else            ls_sm_fsm <= `LS_RD_SM_REQ;
            `LS_RD_SS_WAIT_RS:
                if(ss_rs_ready) ls_sm_fsm <= `LS_DONE;
                else            ls_sm_fsm <= `LS_RD_SS_WAIT_RS;
            `LS_DONE:           
                if(ls_ready)    ls_sm_fsm <= `LS_IDLE;
                else            ls_sm_fsm <= `LS_DONE;
            default:            ls_sm_fsm <= `LS_IDLE;
        endcase
    end
end 


// ------------------------------------------------------
// SS State machine - tracking SS -> LM 
reg [5:0] ss_lm_fsm;

//
// sm fsm state encoding is used to generate related control signal
//  SS read AA inernal  SS_RD     -> SS_RD_SM_RS
//  SS write AA internal SS_WR_S2 -> SS_DONE
// 
//                          {r_ss_cyc, r_ss_wr, r_lm_cyc, r_sm_cyc, w1/w2 or lm_read_ar/r, done}
`define SS_IDLE             6'b0_0_0_0_0_0
`define SS_RD               6'b1_0_0_0_0_0
`define SS_WR_S1            6'b1_1_0_0_0_0
`define SS_WR_S2            6'b1_1_0_0_1_0
`define SS_WR_LM            6'b0_1_1_0_0_0
`define SS_RD_LM_AR         6'b0_0_1_0_0_0
`define SS_RD_LM_R          6'b0_0_1_0_1_0
`define SS_RD_SM_RS         6'b0_0_0_1_0_0
`define SS_DONE             6'b0_0_0_0_0_1

// cycle indicator and control signal generaion
//wire r_ss_cyc = ss_lm_fsm[5] | ss_lm_fsm[3] | ss_lm_fsm[2];
assign r_ss_cyc = ss_lm_fsm[5] | ss_lm_fsm[3] | ss_lm_fsm[2];
wire r_ss_only_cyc = ss_lm_fsm[5];
wire r_ss_wr  = ss_lm_fsm[4];
wire r_lm_cyc = ss_lm_fsm[3];
wire r_ss_sm_cyc = ss_lm_fsm[2];
wire ss_t1  = r_ss_wr & !ss_lm_fsm[1];
//wire ss_t2  = r_ss_wr & ss_lm_fsm[1];
assign ss_t2  = r_ss_wr & ss_lm_fsm[1];
wire ss_done  = ss_lm_fsm[0];

wire r_ss_rd = ~r_ss_wr;

// combine from lm->sm
wire r_sm_cyc = r_ss_sm_cyc | r_ls_sm_cyc;

// interface signals - axis slave
assign aa_as_tready = r_ss_only_cyc;

// interface signal - axis master
//   assign aa_as_tdata 

// LM interface signal - lm master
assign m_awvdlid = r_lm_cyc & r_ss_wr;
assign m_wvalid = m_awvalid;
assign m_arvalid = r_lm_cyc & !r_ss_wr;
assign m_rready  = m_arvalid;

// control signals
// Note: LS, SS state mchine are exclusive
wire ss_aa_internal = ss_aa_reg || ss_aa_mbox;
wire ss_lm_enable = !r_ls_cyc & as_aa_tvalid & !ss_aa_internal;
wire lm_wr_ready  = m_awready & m_wready;

        
// State Machine - ss_lm_fsm
always @(posedge axis_clk or negedge axis_rst_n) begin   // asynchronous reset
    if( !axis_rst_n ) begin
        ss_lm_fsm <= `SS_IDLE;
    end else begin
        case(ss_lm_fsm) 
            `SS_IDLE: 
                if(ss_lm_enable) begin
                    if(ss_wr_cyc)             ss_lm_fsm <=  `SS_WR_S1;
                    else if(ss_rd_cyc)        ss_lm_fsm <= `LS_RD;
                    else                      ss_lm_fsm <= `LS_IDLE;
                end 
                else begin
                    ss_lm_fsm <= `LS_IDLE;
                end
            `SS_WR_S1:  
                if(as_aa_tvalid)   ss_lm_fsm <= `SS_WR_S2;
                else               ss_lm_fsm <= `SS_WR_S1;
            `SS_WR_S2:
                if(as_aa_tvalid)   begin
                    if(ss_aa_reg | ss_aa_mbox)  ss_lm_fsm <= `SS_DONE;
                    else                        ss_lm_fsm <= `SS_WR_LM;
                end 
                else  begin 
                    ss_lm_fsm <= `SS_WR_S2;
                end
            `SS_WR_LM:
                if(lm_wr_ready)     ss_lm_fsm <= `SS_DONE;
                else                ss_lm_fsm <= `SS_WR_LM;
            `SS_RD:
                if(ss_aa_reg | ss_aa_mbox) ss_lm_fsm <= `SS_RD_SM_RS;
                else                      ss_lm_fsm <= `SS_RD_LM_AR;    //read cfg target not in AA
            `SS_RD_LM_AR:
                if( !m_arready )                ss_lm_fsm <= `SS_RD_LM_AR;
                else if( m_arready & !m_rvalid ) ss_lm_fsm <= `SS_RD_LM_R;
                else                            ss_lm_fsm <= `SS_RD_SM_RS;
            `SS_RD_LM_R:
                if( !m_rvalid )      ss_lm_fsm <= `SS_RD_LM_R;
                else                 ss_lm_fsm <= `SS_RD_SM_RS;
            `SS_RD_SM_RS:
                if( !as_aa_tready)   ss_lm_fsm <= `SS_RD_SM_RS;
                else                 ss_lm_fsm <= `SS_DONE;
            `SS_DONE:               ss_lm_fsm <= `SS_IDLE;
            default:            ss_lm_fsm <= `SS_IDLE;
        endcase
    end
end        


// ------------------------------------------------------
//  Address / Data Storage
// ------------------------------------------------------

// ---------   SS    ---------------
// SS - r_ss_rw_addr, r_ss_wdata, r_ss_wstrb, r_tuser
//  - ss side address/data latch
// Note: it does not need reset, why ? when it is used, the content will be valid anyway
// -------------------------

always @( posedge axis_clk ) begin              // T1 - address
    if( r_ss_only_cyc & (!r_ss_wr | ss_t1) & aa_as_tready) begin
        r_ss_rw_addr <= as_aa_tdata;
        r_ss_wstrb <= as_aa_tstrb;
        r_tuser <= as_aa_tuser;
    end else begin
        r_ss_rw_addr <= r_ss_rw_addr;
        r_ss_wstrb <= r_ss_wstrb;
        // r_tuser <= as_aa_tuser;
        r_tuser <= r_tuser;
    end
end

always @(posedge axis_clk) begin                // T2 - data
    if( r_ss_only_cyc & ss_t2 & aa_as_tready) begin
        r_ss_wdata <= aa_as_tdata;
    end else begin
        r_ss_wdata <= r_ss_wdata;
    end
end


// ----------  LS     ---------------------------
// r_ls_rw_addr   - LS address    @awvaid, arvalid
// r_ls_wdata       - LS write data @wvalid
// r_ls_wstrb      - ls write strb @awvalid
// 

always @( posedge axis_clk ) begin
    if( r_ls_only_cyc & (s_awready | s_arready))  begin
        r_ls_rw_addr <= s_awready ? s_awaddr : s_araddr;   // 
    end else begin
        r_ls_rw_addr <= r_ls_rw_addr; 
    end
end
always @( posedge axis_clk ) begin
    if( r_ls_only_cyc & s_wready )  begin
        r_ls_wstrb <= s_wstrb;
        r_ls_wdata <= s_wdata;
    end else begin
        r_ls_wstrb <= r_ls_wstrb;
        r_ls_wdata <= r_ls_wdata;
    end
end


// ---------- LM   --------------------
//  r_lm_rs_data           // latch read response data used for SM to return RS data
//
always @( posedge axis_clk ) begin
    if( ls_sm_fsm == `LS_RD_SS_WAIT_RS & ss_rs_ready ) begin
        r_lm_rs_data <= as_aa_tdata;
    end else begin
        r_lm_rs_data <= r_lm_rs_data;
    end
end
 

endmodule // AXIL_AXIS

