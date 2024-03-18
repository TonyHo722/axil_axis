module tb_test ();

// Clock & Reset - only use axis_clk, axis_rst_n
  reg reset_n;
  reg clk;

// LM - Axilite Master
// LM AW Channel
  wire          m_awvalid;
  wire  [31: 0] m_awaddr;
  reg          m_awready;

// LM  W Channel
  wire          m_wvalid;
  wire  [31: 0] m_wdata;
  wire   [3: 0] m_wstrb;    // follow axis 2nd cycle ss_tdata[31:28]
  reg          m_wready;

/// LM AR Channel
  wire          m_arvalid;
  wire  [31: 0] m_araddr;
  reg          m_arready;

// LM R Channel
  wire          m_rready;
  reg          m_rvalid;
  reg  [31: 0] m_rdata;


// LS - Axilite Slave
// LS AW Channel
  wire          s_awready;
  reg          s_awvalid;
  reg  [14: 0] s_awaddr;

// LS W Channel
  wire          s_wready;
  reg          s_wvalid;
  reg  [31: 0] s_wdata;
  reg   [3: 0] s_wstrb;

// LS AR Channel
  wire          s_arready;
  reg          s_arvalid;
  reg  [14: 0] s_araddr;

 // LS R Channel
  wire  [31: 0] s_rdata;
  wire          s_rvalid;
  reg          s_rready;

// -- Stream Interface with Axi-Switch (AS)

// SS - Stream Slave
  reg  [31: 0] as_aa_tdata;
  reg   [3: 0] as_aa_tstrb;
  reg   [3: 0] as_aa_tkeep;
  reg          as_aa_tlast;
  reg          as_aa_tvalid;
  reg   [1: 0] as_aa_tuser;
  reg         aa_as_tready;

// SM - Stream Master
  wire  [31: 0] aa_as_tdata;
  wire   [3: 0] aa_as_tstrb;
  wire   [3: 0] aa_as_tkeep;
  wire          aa_as_tlast;
  wire          aa_as_tvalid;
  wire   [1: 0] aa_as_tuser;
  reg          as_aa_tready;

// Misc
  reg          cc_aa_enable;   // all Axilite Slave transaction should be qualified by cc_aa_enable
  wire          mb_irq;          // Generate interrupt only when mailbox write by remote, i.e. from Axi-stream


  AXIL_AXIS dut(

// Clock & Reset - only use axis_clk, axis_rst_n
  .axi_clk(clk),
  .axi_reset_n(reset_n),
  .axis_clk(clk),
  .axis_rst_n(reset_n),

// LM - Axilite Master
// LM AW Channel
  .m_awvalid(m_awvalid),
  .m_awaddr(m_awaddr),
  .m_awready(m_awready),

// LM  W Channel
  .m_wvalid(m_wvalid),
  .m_wdata(m_wdata),
  .m_wstrb(m_wstrb),
  .m_wready(m_wready),

/// LM AR Channel
  .m_arvalid(m_arvalid),
  .m_araddr(m_araddr),
  .m_arready(m_arready),

// LM R Channel
  .m_rready(m_rready),
  .m_rvalid(m_rvalid),
  .m_rdata(m_rdata),

// LS - Axilite Slave
// LS AW Channel
  .s_awready(s_awready),
  .s_awvalid(s_awvalid),
  .s_awaddr(s_awaddr),

// LS W Channel
  .s_wready(s_wready),
  .s_wvalid(s_wvalid),
  .s_wdata(s_wdata),
  .s_wstrb(s_wstrb),

// LS AR Channel
  .s_arready(s_arready),
  .s_arvalid(s_arvalid),
  .s_araddr(s_araddr),

 // LS R Channel
  .s_rdata(s_rdata),
  .s_rvalid(s_rvalid),
  .s_rready(s_rready),

// -- Stream Interface with Axi-Switch (AS)
// SS - Stream Slave
  .as_aa_tdata(as_aa_tdata),
  .as_aa_tstrb(as_aa_tstrb),
  .as_aa_tkeep(as_aa_tkeep),
  .as_aa_tlast(as_aa_tlast),
  .as_aa_tvalid(as_aa_tvalid),
  .as_aa_tuser(as_aa_tuser),
  .aa_as_tready(aa_as_tready),

// SM - Stream Master
  .aa_as_tdata(aa_as_tdata),
  .aa_as_tstrb(aa_as_tstrb),
  .aa_as_tkeep(aa_as_tkeep),
  .aa_as_tlast(aa_as_tlast),
  .aa_as_tvalid(aa_as_tvalid),
  .aa_as_tuser(aa_as_tuser),
  .as_aa_tready(as_aa_tready),

// Misc
  .cc_aa_enable(cc_aa_enable),
  .mb_irq(mb_irq)

  );


  initial begin
    clk = 0;
    reset_n = 0;
    init_value();
    
    #50;
    reset_n = 1;
    #100;
    @ (posedge clk);
    soc_to_internal_aa_reg_access();
    
    @ (posedge clk);
    //soc_to_fpga_cfg_access();
    
    #100;
    $finish;
  end

  always #(5) clk = ~clk;

  task init_value;
    begin
// LM - Axilite Master
// LM AW Channel   
      m_awready = 0;

// LM  W Channel
      m_wready = 0;

/// LM AR Channel      
      m_arready = 0;
      
// LM R Channel      
      m_rvalid = 0;
      m_rdata = 0;
      
// LS - Axilite Slave
// LS AW Channel
      s_awvalid = 0;
      s_awaddr = 0;
      
// LS W Channel
      s_wvalid = 0;
      s_wdata = 0;
      s_wstrb = 0;

// LS AR Channel      
      s_arvalid = 0;
      s_araddr = 0;

 // LS R Channel      
      s_rready = 0;

// SS - Stream Slave
      as_aa_tdata = 0;
      as_aa_tstrb = 0;
      as_aa_tkeep = 0;
      as_aa_tlast = 0;
      as_aa_tvalid = 0;
      as_aa_tuser = 0;

// SM - Stream Master
      as_aa_tready = 0;

// Misc
      cc_aa_enable = 1;
   
    end
  endtask


  task fpga_to_soc_cfg_access;
    begin
      ls_cfg_w( 15'h0000, 32'h5a5a5a5a, 4'b1111);  //write to UP 
      ls_cfg_r( 15'h0000);  //read UP
    end
  endtask


  task soc_to_internal_aa_reg_access;
    begin
      ls_cfg_r( 15'h100);  //read soc aa_reg intr_enable
      ls_cfg_w( 15'h100, 32'h1, 4'b001);  //set soc aa_reg intr_enable = 1
      ls_cfg_r( 15'h100);  //read soc aa_reg intr_enable
    end
  endtask
    

  task ls_cfg_w;
    input [14:0] address;
    input [3:0] wstrb;
    input [31:0] data;
    begin
      s_awaddr <= address;
      s_awvalid <= 1'b1;
      s_wdata <= data;
      s_wstrb <= wstrb;
      s_wvalid <= 1'b1;
      
      $display($time, "=> ls_cfg_w %x, %x, %x", address, wstrb, data);
      
      @ (posedge clk);
      while (s_awready == 0 || s_wready == 0) begin            // LS must set both s_awready == 1 and s_wready == 1
        @ (posedge clk);
      end
      s_awvalid <= 1'b0;
      s_wvalid <= 1'b0;

      @ (posedge clk);

    end
  endtask


  reg [31:0] cfg_read_data;
  task ls_cfg_r;
    input [14:0] address;
    begin
      s_araddr <= address;
      s_arvalid <= 1'b1;

      $display($time, "=> ls_cfg_r %x", address);
      
      @ (posedge clk);
      while (s_arready == 0 ) begin
        @ (posedge clk);
      end
      
      s_arvalid <= 1'b0;
      s_rready <= 1'b1;

      @ (posedge clk);
      while (s_rvalid == 0 ) begin
        @ (posedge clk);
      end
      s_rready <= 1'b0;
      cfg_read_data <= s_rdata;

      @ (posedge clk);

      $display($time, "=> ls_cfg_r result = %x", cfg_read_data);

    end
  endtask

  task fpga_to_soc_cfg_write_req;
    input [14:0] address;
    input [31:0] data;
    input [3:0] wstrb;
    begin
      s_awaddr <= address;
      s_awvalid <= 1'b1;
      s_wdata <= data;
      s_wstrb <= wstrb;
      s_wvalid <= 1'b1;
      
      $display($time, "=> soc_internal_axilite_write_req %x, %x, %x", address, wstrb, data);
      
      @ (posedge clk);
      while (s_awready == 0 || s_wready == 0) begin            // LS must set both s_awready == 1 and s_wready == 1
        @ (posedge clk);
      end
      s_awvalid <= 1'b0;
      s_wvalid <= 1'b0;

      @ (posedge clk);

    end
  endtask

endmodule

