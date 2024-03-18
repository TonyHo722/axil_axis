module tb_test ();

// Clock & Reset - only use axis_clk, axis_rst_n
  reg reset_n;
  reg clk;

// LM - Axilite Master
// LM AW Channel
  wire          soc_m_awvalid;
  wire  [31: 0] soc_m_awaddr;
  reg          soc_m_awready;

// LM  W Channel
  wire          soc_m_wvalid;
  wire  [31: 0] soc_m_wdata;
  wire   [3: 0] soc_m_wstrb;    // follow axis 2nd cycle ss_tdata[31:28]
  reg          soc_m_wready;

/// LM AR Channel
  wire          soc_m_arvalid;
  wire  [31: 0] soc_m_araddr;
  reg          soc_m_arready;

// LM R Channel
  wire          soc_m_rready;
  reg          soc_m_rvalid;
  reg  [31: 0] soc_m_rdata;


// LS - Axilite Slave
// LS AW Channel
  wire          soc_s_awready;
  reg          soc_s_awvalid;
  reg  [14: 0] soc_s_awaddr;

// LS W Channel
  wire          soc_s_wready;
  reg          soc_s_wvalid;
  reg  [31: 0] soc_s_wdata;
  reg   [3: 0] soc_s_wstrb;

// LS AR Channel
  wire          soc_s_arready;
  reg          soc_s_arvalid;
  reg  [14: 0] soc_s_araddr;

 // LS R Channel
  wire  [31: 0] soc_s_rdata;
  wire          soc_s_rvalid;
  reg          soc_s_rready;

// -- Stream Interface with Axi-Switch (AS)

// SS - Stream Slave
//  reg  [31: 0] soc_as_aa_tdata;
//  reg   [3: 0] soc_as_aa_tstrb;
//  reg   [3: 0] soc_as_aa_tkeep;
//  reg          soc_as_aa_tlast;
//  reg          soc_as_aa_tvalid;
//  reg   [1: 0] soc_as_aa_tuser;
//  wire         soc_aa_as_tready;

// SM - Stream Master
//  wire  [31: 0] soc_aa_as_tdata;
//  wire   [3: 0] soc_aa_as_tstrb;
//  wire   [3: 0] soc_aa_as_tkeep;
//  wire          soc_aa_as_tlast;
//  wire          soc_aa_as_tvalid;
//  wire   [1: 0] soc_aa_as_tuser;
//  reg          soc_as_aa_tready;

// Misc
  reg          soc_cc_aa_enable;   // all Axilite Slave transaction should be qualified by cc_aa_enable
  wire          soc_mb_irq;          // Generate interrupt only when mailbox write by remote, i.e. from Axi-stream

// LM - Axilite Master
// LM AW Channel
  wire          fpga_m_awvalid;
  wire  [31: 0] fpga_m_awaddr;
  reg          fpga_m_awready;

// LM  W Channel
  wire          fpga_m_wvalid;
  wire  [31: 0] fpga_m_wdata;
  wire   [3: 0] fpga_m_wstrb;    // follow axis 2nd cycle ss_tdata[31:28]
  reg          fpga_m_wready;

/// LM AR Channel
  wire          fpga_m_arvalid;
  wire  [31: 0] fpga_m_araddr;
  reg          fpga_m_arready;

// LM R Channel
  wire          fpga_m_rready;
  reg          fpga_m_rvalid;
  reg  [31: 0] fpga_m_rdata;


// LS - Axilite Slave
// LS AW Channel
  wire          fpga_s_awready;
  reg          fpga_s_awvalid;
  reg  [14: 0] fpga_s_awaddr;

// LS W Channel
  wire          fpga_s_wready;
  reg          fpga_s_wvalid;
  reg  [31: 0] fpga_s_wdata;
  reg   [3: 0] fpga_s_wstrb;

// LS AR Channel
  wire          fpga_s_arready;
  reg          fpga_s_arvalid;
  reg  [14: 0] fpga_s_araddr;

 // LS R Channel
  wire  [31: 0] fpga_s_rdata;
  wire          fpga_s_rvalid;
  reg          fpga_s_rready;

// -- Stream Interface with Axi-Switch (AS)

// SS - Stream Slave
//  reg  [31: 0] fpga_as_aa_tdata;
//  reg   [3: 0] fpga_as_aa_tstrb;
//  reg   [3: 0] fpga_as_aa_tkeep;
//  reg          fpga_as_aa_tlast;
//  reg          fpga_as_aa_tvalid;
//  reg   [1: 0] fpga_as_aa_tuser;
//  wire         fpga_aa_as_tready;

// SM - Stream Master
//  wire  [31: 0] fpga_aa_as_tdata;
//  wire   [3: 0] fpga_aa_as_tstrb;
//  wire   [3: 0] fpga_aa_as_tkeep;
//  wire          fpga_aa_as_tlast;
//  wire          fpga_aa_as_tvalid;
//  wire   [1: 0] fpga_aa_as_tuser;
//  reg          fpga_as_aa_tready;

// Misc
  reg          fpga_cc_aa_enable;   // all Axilite Slave transaction should be qualified by cc_aa_enable
  wire          fpga_mb_irq;          // Generate interrupt only when mailbox write by remote, i.e. from Axi-stream


  wire  [31: 0] soc_sm_tdata;
  wire   [3: 0] soc_sm_tstrb;
  wire   [3: 0] soc_sm_tkeep;
  wire          soc_sm_tlast;
  wire          soc_sm_tvalid;
  wire   [1: 0] soc_sm_tuser;
  wire          soc_ss_tready;

  wire  [31: 0] fpga_sm_tdata;
  wire   [3: 0] fpga_sm_tstrb;
  wire   [3: 0] fpga_sm_tkeep;
  wire          fpga_sm_tlast;
  wire          fpga_sm_tvalid;
  wire   [1: 0] fpga_sm_tuser;
  wire          fpga_ss_tready;

  AXIL_AXIS soc(

// Clock & Reset - only use axis_clk, axis_rst_n
  .axi_clk(clk),
  .axi_reset_n(reset_n),
  .axis_clk(clk),
  .axis_rst_n(reset_n),

// LM - Axilite Master
// LM AW Channel
  .m_awvalid(soc_m_awvalid),
  .m_awaddr(soc_m_awaddr),
  .m_awready(soc_m_awready),

// LM  W Channel
  .m_wvalid(soc_m_wvalid),
  .m_wdata(soc_m_wdata),
  .m_wstrb(soc_m_wstrb),
  .m_wready(soc_m_wready),

/// LM AR Channel
  .m_arvalid(soc_m_arvalid),
  .m_araddr(soc_m_araddr),
  .m_arready(soc_m_arready),

// LM R Channel
  .m_rready(soc_m_rready),
  .m_rvalid(soc_m_rvalid),
  .m_rdata(soc_m_rdata),

// LS - Axilite Slave
// LS AW Channel
  .s_awready(soc_s_awready),
  .s_awvalid(soc_s_awvalid),
  .s_awaddr(soc_s_awaddr),

// LS W Channel
  .s_wready(soc_s_wready),
  .s_wvalid(soc_s_wvalid),
  .s_wdata(soc_s_wdata),
  .s_wstrb(soc_s_wstrb),

// LS AR Channel
  .s_arready(soc_s_arready),
  .s_arvalid(soc_s_arvalid),
  .s_araddr(soc_s_araddr),

 // LS R Channel
  .s_rdata(soc_s_rdata),
  .s_rvalid(soc_s_rvalid),
  .s_rready(soc_s_rready),

// -- Stream Interface with Axi-Switch (AS)
// SS - Stream Slave
  .as_aa_tdata(fpga_sm_tdata),   // I - fpga AA_SM -> soc AA_SS
  .as_aa_tstrb(fpga_sm_tstrb),   // I 
  .as_aa_tkeep(fpga_sm_tkeep),   // I 
  .as_aa_tlast(fpga_sm_tlast),   // I 
  .as_aa_tvalid(fpga_sm_tvalid),   // I 
  .as_aa_tuser(fpga_sm_tuser),   // I 
  .aa_as_tready(soc_ss_tready),    // O 

// SM - Stream Master
  .aa_as_tdata(soc_sm_tdata),    //O
  .aa_as_tstrb(soc_sm_tstrb),    //O
  .aa_as_tkeep(soc_sm_tkeep),    //O
  .aa_as_tlast(soc_sm_tlast),    //O
  .aa_as_tvalid(soc_sm_tvalid),    //O
  .aa_as_tuser(soc_sm_tuser),    //O
  .as_aa_tready(fpga_ss_tready),   //I - fpga AA_SS -> soc AA_SM

// Misc
  .cc_aa_enable(soc_cc_aa_enable),
  .mb_irq(soc_mb_irq)

  );

  AXIL_AXIS fpga(

// Clock & Reset - only use axis_clk, axis_rst_n
  .axi_clk(clk),
  .axi_reset_n(reset_n),
  .axis_clk(clk),
  .axis_rst_n(reset_n),

// LM - Axilite Master
// LM AW Channel
  .m_awvalid(fpga_m_awvalid),
  .m_awaddr(fpga_m_awaddr),
  .m_awready(fpga_m_awready),

// LM  W Channel
  .m_wvalid(fpga_m_wvalid),
  .m_wdata(fpga_m_wdata),
  .m_wstrb(fpga_m_wstrb),
  .m_wready(fpga_m_wready),

/// LM AR Channel
  .m_arvalid(fpga_m_arvalid),
  .m_araddr(fpga_m_araddr),
  .m_arready(fpga_m_arready),

// LM R Channel
  .m_rready(fpga_m_rready),
  .m_rvalid(fpga_m_rvalid),
  .m_rdata(fpga_m_rdata),

// LS - Axilite Slave
// LS AW Channel
  .s_awready(fpga_s_awready),
  .s_awvalid(fpga_s_awvalid),
  .s_awaddr(fpga_s_awaddr),

// LS W Channel
  .s_wready(fpga_s_wready),
  .s_wvalid(fpga_s_wvalid),
  .s_wdata(fpga_s_wdata),
  .s_wstrb(fpga_s_wstrb),

// LS AR Channel
  .s_arready(fpga_s_arready),
  .s_arvalid(fpga_s_arvalid),
  .s_araddr(fpga_s_araddr),

 // LS R Channel
  .s_rdata(fpga_s_rdata),
  .s_rvalid(fpga_s_rvalid),
  .s_rready(fpga_s_rready),

// -- Stream Interface with Axi-Switch (AS)
// SS - Stream Slave
  .as_aa_tdata(soc_sm_tdata),   //I - soc AA_SM -> fpga AA_SS
  .as_aa_tstrb(soc_sm_tstrb),    //I 
  .as_aa_tkeep(soc_sm_tkeep),    //I 
  .as_aa_tlast(soc_sm_tlast),    //I 
  .as_aa_tvalid(soc_sm_tvalid),    //I 
  .as_aa_tuser(soc_sm_tuser),    //I 
  .aa_as_tready(fpga_ss_tready),   //O

// SM - Stream Master
  .aa_as_tdata(fpga_sm_tdata),   //O
  .aa_as_tstrb(fpga_sm_tstrb),   //O
  .aa_as_tkeep(fpga_sm_tkeep),   //O
  .aa_as_tlast(fpga_sm_tlast),   //O
  .aa_as_tvalid(fpga_sm_tvalid),   //O
  .aa_as_tuser(fpga_sm_tuser),   //O
  .as_aa_tready(soc_ss_tready),    //I - soc AA_SS -> fpga AA_SM

// Misc
  .cc_aa_enable(fpga_cc_aa_enable),
  .mb_irq(fpga_mb_irq)

  );

  initial begin
    clk = 0;
    reset_n = 0;
    soc_init_value();
    fpga_init_value();
    
    #50;
    reset_n = 1;
    #100;
    @ (posedge clk);
    soc_to_internal_aa_reg_access();
    
    @ (posedge clk);
    fpga_to_soc_cfg_access();
    
    #100;
    $finish;
  end

  always #(5) clk = ~clk;

  task soc_init_value;
    begin
// LM - Axilite Master
// LM AW Channel   
      soc_m_awready = 0;

// LM  W Channel
      soc_m_wready = 0;

/// LM AR Channel      
      soc_m_arready = 0;
      
// LM R Channel      
      soc_m_rvalid = 0;
      soc_m_rdata = 0;
      
// LS - Axilite Slave
// LS AW Channel
      soc_s_awvalid = 0;
      soc_s_awaddr = 0;
      
// LS W Channel
      soc_s_wvalid = 0;
      soc_s_wdata = 0;
      soc_s_wstrb = 0;

// LS AR Channel      
      soc_s_arvalid = 0;
      soc_s_araddr = 0;

 // LS R Channel      
      soc_s_rready = 0;

// SS - Stream Slave
//      soc_as_aa_tdata = 0;
//      soc_as_aa_tstrb = 0;
//      soc_as_aa_tkeep = 0;
//      soc_as_aa_tlast = 0;
//      soc_as_aa_tvalid = 0;
//      soc_as_aa_tuser = 0;

// SM - Stream Master
//      soc_as_aa_tready = 0;

// Misc
      soc_cc_aa_enable = 1;
   
    end
  endtask

  task fpga_init_value;
    begin
// LM - Axilite Master
// LM AW Channel   
      fpga_m_awready = 0;

// LM  W Channel
      fpga_m_wready = 0;

/// LM AR Channel      
      fpga_m_arready = 0;
      
// LM R Channel      
      fpga_m_rvalid = 0;
      fpga_m_rdata = 0;
      
// LS - Axilite Slave
// LS AW Channel
      fpga_s_awvalid = 0;
      fpga_s_awaddr = 0;
      
// LS W Channel
      fpga_s_wvalid = 0;
      fpga_s_wdata = 0;
      fpga_s_wstrb = 0;

// LS AR Channel      
      fpga_s_arvalid = 0;
      fpga_s_araddr = 0;

 // LS R Channel      
      fpga_s_rready = 0;

// SS - Stream Slave
//      fpga_as_aa_tdata = 0;
//      fpga_as_aa_tstrb = 0;
//      fpga_as_aa_tkeep = 0;
//      fpga_as_aa_tlast = 0;
//      fpga_as_aa_tvalid = 0;
//      fpga_as_aa_tuser = 0;

// SM - Stream Master
//      fpga_as_aa_tready = 0;

// Misc
      fpga_cc_aa_enable = 1;
   
    end
  endtask


  task fpga_to_soc_cfg_access;
    begin
      fpga_ls_cfg_w( 15'h0000, 4'b1111, 32'h5a5a5a5a);  //write to UP in soc
      fpga_ls_cfg_r( 15'h0000);  //read UP in soc
    end
  endtask

/*

wire up_reg = ( m_awaddr[31:12] == 20'h0000_0 );

  //UP axil slave interface connect to lm
  always @( posedge clk or negedge reset_n) begin
    if ( reset_n ) begin
      m_awready <= 1'b0;
      m_wready <= 1'b0;

    end else begin 
      if ( m_awvalid && m_wvalid && !m_awready && !m_wready && up_reg) begin
        m_awready <= 1'b1;
        m_wready <= 1'b1;
      end  
      else begin
        m_awready <= 1'b0;
        m_wready <= 1'b0;
      end
    end
  end    

  reg   [31:0] up_regs[7:0];   // support 8*DW
  
  inital  begin
    //when lm write UP then save the data.
    while (1) begin
      @(posedge clk);
      if (m_awvalid && m_wvalid && m_awready && m_wready && up_reg && (|m_wstrb) begin
        if (m_awaddr[11:5] == 0 ) begin
          if ( m_wstrb[0] ) up_regs[m_awaddr[4:2]][7:0] <= m_wdata[7:0];
          else              up_regs[m_awaddr[4:2]][7:0] <= up_regs[m_awaddr[4:2]][7:0];
          if ( m_wstrb[1] ) up_regs[m_awaddr[4:2]][15:8] <= m_wdata[15:8];
          else              up_regs[m_awaddr[4:2]][15:8] <= up_regs[m_awaddr[4:2]][15:8];
          if ( m_wstrb[2] ) up_regs[m_awaddr[4:2]][23:16] <= m_wdata[23:16];
          else              up_regs[m_awaddr[4:2]][23:16] <= up_regs[m_awaddr[4:2]][23:16];
          if ( m_wstrb[3] ) up_regs[m_awaddr[4:2]][31:24] <= m_wdata[31:24];
          else              up_regs[m_awaddr[4:2]][31:24] <= up_regs[m_awaddr[4:2]][31:24];
        end        
        $display($time, "=> LM write UP %x, %x, %x", m_awaddr, m_wstrb, m_wdata); 
      end      
    end    
  end

  //remote AS_SS interface connect to AA_SM
  always @( posedge clk or negedge reset_n) begin
    if ( reset_n ) begin
      as_aa_tready <= 1'b0;

    end else begin 
      if ( aa_as_tvalid && !as_aa_tready ) begin
        as_aa_tready <= 1'b1;
      end  
      else begin
        as_aa_tready <= 1'b0;
      end
    end
  end    

  reg  [31: 0] save_aa_as_tdata,
  reg   [3: 0] save_aa_as_tstrb,
  reg   [3: 0] save_aa_as_tkeep,
  reg          save_aa_as_tlast,
  reg   [1: 0] save_aa_as_tuser,

  output wire   [3: 0] aa_as_tstrb,
  output wire   [3: 0] aa_as_tkeep,
  output wire          aa_as_tlast,
  output wire          aa_as_tvalid,
  output wire   [1: 0] aa_as_tuser,

  
  inital  begin
    //when lm write UP then save the data.
    while (1) begin
      @(posedge clk);
      if (aa_as_tvalid && as_aa_tready ) begin
        save_aa_as_tdata <= aa_as_tdata;
        save_aa_as_tstrb <= aa_as_tstrb;
        save_aa_as_tkeep <= aa_as_tkeep;
        save_aa_as_tlast <= aa_as_tlast;
        save_aa_as_tuser <= aa_as_tuser;
        $display($time, "=> AA_SM write AS_SS %x, %x, %x, %x, %x", aa_as_tdata, aa_as_tstrb, aa_as_tkeep, aa_as_tlast, aa_as_tuser); 
      end      
    end    
  end
*/


  task soc_to_internal_aa_reg_access;
    begin
      soc_ls_cfg_r( 15'h100);  //read soc aa_reg intr_enable
      soc_ls_cfg_w( 15'h100, 32'h1, 4'b001);  //set soc aa_reg intr_enable = 1
      soc_ls_cfg_r( 15'h100);  //read soc aa_reg intr_enable
    end
  endtask
    

  task soc_ls_cfg_w;
    input [14:0] address;
    input [3:0] wstrb;
    input [31:0] data;
    begin
      soc_s_awaddr <= address;
      soc_s_awvalid <= 1'b1;
      soc_s_wdata <= data;
      soc_s_wstrb <= wstrb;
      soc_s_wvalid <= 1'b1;
      
      $display($time, "=> soc_ls_cfg_w %x, %x, %x", address, wstrb, data);
      
      @ (posedge clk);
      while (soc_s_awready == 0 || soc_s_wready == 0) begin            // LS must set both s_awready == 1 and s_wready == 1
        @ (posedge clk);
      end
      soc_s_awvalid <= 1'b0;
      soc_s_wvalid <= 1'b0;

      @ (posedge clk);

    end
  endtask


  reg [31:0] soc_cfg_read_data;
  task soc_ls_cfg_r;
    input [14:0] address;
    begin
      soc_s_araddr <= address;
      soc_s_arvalid <= 1'b1;

      $display($time, "=> ls_cfg_r %x", address);
      
      @ (posedge clk);
      while (soc_s_arready == 0 ) begin
        @ (posedge clk);
      end
      
      soc_s_arvalid <= 1'b0;
      soc_s_rready <= 1'b1;

      @ (posedge clk);
      while (soc_s_rvalid == 0 ) begin
        @ (posedge clk);
      end
      soc_s_rready <= 1'b0;
      soc_cfg_read_data <= soc_s_rdata;

      @ (posedge clk);

      $display($time, "=> soc_ls_cfg_r result = %x", soc_cfg_read_data);

    end
  endtask

  task fpga_ls_cfg_w;
    input [14:0] address;
    input [3:0] wstrb;
    input [31:0] data;
    begin
      fpga_s_awaddr <= address;
      fpga_s_awvalid <= 1'b1;
      fpga_s_wdata <= data;
      fpga_s_wstrb <= wstrb;
      fpga_s_wvalid <= 1'b1;
      
      $display($time, "=> fpga_ls_cfg_w %x, %x, %x", address, wstrb, data);
      
      @ (posedge clk);
      while (fpga_s_awready == 0 || fpga_s_wready == 0) begin            // LS must set both s_awready == 1 and s_wready == 1
        @ (posedge clk);
      end
      fpga_s_awvalid <= 1'b0;
      fpga_s_wvalid <= 1'b0;

      @ (posedge clk);

    end
  endtask


  reg [31:0] fpga_cfg_read_data;
  task fpga_ls_cfg_r;
    input [14:0] address;
    begin
      fpga_s_araddr <= address;
      fpga_s_arvalid <= 1'b1;

      $display($time, "=> ls_cfg_r %x", address);
      
      @ (posedge clk);
      while (fpga_s_arready == 0 ) begin
        @ (posedge clk);
      end
      
      fpga_s_arvalid <= 1'b0;
      fpga_s_rready <= 1'b1;

      @ (posedge clk);
      while (fpga_s_rvalid == 0 ) begin
        @ (posedge clk);
      end
      fpga_s_rready <= 1'b0;
      fpga_cfg_read_data <= fpga_s_rdata;

      @ (posedge clk);

      $display($time, "=> fpga_ls_cfg_r result = %x", fpga_cfg_read_data);

    end
  endtask

/*
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
*/

endmodule

