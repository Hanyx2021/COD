`default_nettype none

module thinpad_top (
    input wire clk_50M,     // 50MHz 时钟输入
    input wire clk_11M0592, // 11.0592MHz 时钟输入（备用，可不用）

    input wire push_btn,  // BTN5 按钮�????关，带消抖电路，按下时为 1
    input wire reset_btn, // BTN6 复位按钮，带消抖电路，按下时�???? 1

    input  wire [ 3:0] touch_btn,  // BTN1~BTN4，按钮开关，按下时为 1
    input  wire [31:0] dip_sw,     // 32 位拨码开关，拨到“ON”时�???? 1
    output wire [15:0] leds,       // 16 �???? LED，输出时 1 点亮
    output wire [ 7:0] dpy0,       // 数码管低位信号，包括小数点，输出 1 点亮
    output wire [ 7:0] dpy1,       // 数码管高位信号，包括小数点，输出 1 点亮

    // CPLD 串口控制器信�????
    output wire uart_rdn,        // 读串口信号，低有�????
    output wire uart_wrn,        // 写串口信号，低有�????
    input  wire uart_dataready,  // 串口数据准备�????
    input  wire uart_tbre,       // 发�?�数据标�????
    input  wire uart_tsre,       // 数据发�?�完毕标�????

    // BaseRAM 信号
    inout wire [31:0] base_ram_data,  // BaseRAM 数据，低 8 位与 CPLD 串口控制器共�????
    output wire [19:0] base_ram_addr,  // BaseRAM 地址
    output wire [3:0] base_ram_be_n,  // BaseRAM 字节使能，低有效。如果不使用字节使能，请保持�???? 0
    output wire base_ram_ce_n,  // BaseRAM 片�?�，低有�????
    output wire base_ram_oe_n,  // BaseRAM 读使能，低有�????
    output wire base_ram_we_n,  // BaseRAM 写使能，低有�????

    // ExtRAM 信号
    inout wire [31:0] ext_ram_data,  // ExtRAM 数据
    output wire [19:0] ext_ram_addr,  // ExtRAM 地址
    output wire [3:0] ext_ram_be_n,  // ExtRAM 字节使能，低有效。如果不使用字节使能，请保持�???? 0
    output wire ext_ram_ce_n,  // ExtRAM 片�?�，低有�????
    output wire ext_ram_oe_n,  // ExtRAM 读使能，低有�????
    output wire ext_ram_we_n,  // ExtRAM 写使能，低有�????

    // 直连串口信号
    output wire txd,  // 直连串口发�?�端
    input  wire rxd,  // 直连串口接收�????

    // Flash 存储器信号，参�?? JS28F640 芯片手册
    output wire [22:0] flash_a,  // Flash 地址，a0 仅在 8bit 模式有效�????16bit 模式无意�????
    inout wire [15:0] flash_d,  // Flash 数据
    output wire flash_rp_n,  // Flash 复位信号，低有效
    output wire flash_vpen,  // Flash 写保护信号，低电平时不能擦除、烧�????
    output wire flash_ce_n,  // Flash 片�?�信号，低有�????
    output wire flash_oe_n,  // Flash 读使能信号，低有�????
    output wire flash_we_n,  // Flash 写使能信号，低有�????
    output wire flash_byte_n, // Flash 8bit 模式选择，低有效。在使用 flash �???? 16 位模式时请设�???? 1

    // USB 控制器信号，参�?? SL811 芯片手册
    output wire sl811_a0,
    // inout  wire [7:0] sl811_d,     // USB 数据线与网络控制器的 dm9k_sd[7:0] 共享
    output wire sl811_wr_n,
    output wire sl811_rd_n,
    output wire sl811_cs_n,
    output wire sl811_rst_n,
    output wire sl811_dack_n,
    input  wire sl811_intrq,
    input  wire sl811_drq_n,

    // 网络控制器信号，参�?? DM9000A 芯片手册
    output wire dm9k_cmd,
    inout wire [15:0] dm9k_sd,
    output wire dm9k_iow_n,
    output wire dm9k_ior_n,
    output wire dm9k_cs_n,
    output wire dm9k_pwrst_n,
    input wire dm9k_int,

    // 图像输出信号
    output wire [2:0] video_red,    // 红色像素�????3 �????
    output wire [2:0] video_green,  // 绿色像素�????3 �????
    output wire [1:0] video_blue,   // 蓝色像素�????2 �????
    output wire       video_hsync,  // 行同步（水平同步）信�????
    output wire       video_vsync,  // 场同步（垂直同步）信�????
    output wire       video_clk,    // 像素时钟输出
    output wire       video_de      // 行数据有效信号，用于区分消隐�????
);

  /* =========== Demo code begin =========== */

  // PLL 分频示例
  logic locked, clk_10M, clk_20M;
  pll_example clock_gen (
      // Clock in ports
      .clk_in1(clk_50M),  // 外部时钟输入
      // Clock out ports
      .clk_out1(clk_10M),  // 时钟输出 1，频率在 IP 配置界面中设�????
      .clk_out2(clk_20M),  // 时钟输出 2，频率在 IP 配置界面中设�????
      // Status and control signals
      .reset(reset_btn),  // PLL 复位输入
      .locked(locked)  // PLL 锁定指示输出�????"1"表示时钟稳定�????
                       // 后级电路复位信号应当由它生成（见下）
  );

  logic reset_of_clk10M;
  // 异步复位，同步释放，�???? locked 信号转为后级电路的复�???? reset_of_clk10M
  always_ff @(posedge clk_10M or negedge locked) begin
    if (~locked) reset_of_clk10M <= 1'b1;
    else reset_of_clk10M <= 1'b0;
  end

  /* =========== Demo code end =========== */

  logic sys_clk;
  logic sys_rst;

  assign sys_clk = clk_10M;
  assign sys_rst = reset_of_clk10M;

  // 本实验不使用 CPLD 串口，禁用防止�?�线冲突
  assign uart_rdn = 1'b1;
  assign uart_wrn = 1'b1;


  /* ============ ALU  and  Register =============*/
  logic [3:0]alu_op;
  logic [31:0]alu_a;
  logic [31:0]alu_b;
  logic [31:0]alu_y;
  logic [5:0]rf_waddr;
  logic [31:0]rf_wdata;
  logic [5:0]raddr_a;
  logic [31:0]rdata_a;
  logic [5:0]raddr_b;
  logic [31:0]rdata_b;
  logic [11:0]csrindex;
  logic [5:0]csrreg;
  logic [11:0]csrindex_2;
  logic [5:0]csrreg_2;
  logic [31:0]csr_wdata;
  logic rf_we;
  logic rf_we_csr;

    register u_reg(
    .clk(sys_clk),
    .reset(sys_rst),
    .waddr(rf_waddr),
    .wdata(rf_wdata),
    .raddr_a(raddr_a),
    .rdata_a(rdata_a),
    .raddr_b(raddr_b),
    .rdata_b(rdata_b),
    .we(rf_we),
    .waddr_csr(csrreg_2),
    .wdata_csr(csr_wdata),
    .we_csr(rf_we_csr)
  );
  
  csr_converter csrconv_1(
    .csrindex(csrindex),
    .csrreg(csrreg)
  );

  csr_converter csrconv_2(
    .csrindex(csrindex_2),
    .csrreg(csrreg_2)
  );

     ALU u_alu(
      .op(alu_op),
      .rs1(alu_a),
      .rs2(alu_b),
      .rd(alu_y)
     );

    /* ============ ALU  and  Register end =============*/


  /* =========== Lab6 MUX begin =========== */
  // Wishbone MUX (Masters) => bus slaves
  logic wbs0_cyc_o;
  logic wbs0_stb_o;
  logic wbs0_ack_i;
  logic [31:0] wbs0_adr_o;
  logic [31:0] wbs0_dat_o;
  logic [31:0] wbs0_dat_i;
  logic [3:0] wbs0_sel_o;
  logic wbs0_we_o;

  logic wbs1_cyc_o;
  logic wbs1_stb_o;
  logic wbs1_ack_i;
  logic [31:0] wbs1_adr_o;
  logic [31:0] wbs1_dat_o;
  logic [31:0] wbs1_dat_i;
  logic [3:0] wbs1_sel_o;
  logic wbs1_we_o;

  logic wbs2_cyc_o;
  logic wbs2_stb_o;
  logic wbs2_ack_i;
  logic [31:0] wbs2_adr_o;
  logic [31:0] wbs2_dat_o;
  logic [31:0] wbs2_dat_i;
  logic [3:0] wbs2_sel_o;
  logic wbs2_we_o;

  logic        arb_cyc_o;
  logic        arb_stb_o;
  logic        arb_ack_i;
  logic [31:0] arb_adr_o;
  logic [31:0] arb_dat_o;
  logic [31:0] arb_dat_i;
  logic [ 3:0] arb_sel_o;
  logic        arb_we_o;

  wb_mux_3 wb_mux (
      .clk(sys_clk),
      .rst(sys_rst),

      // Master interface (to arbiter)
      .wbm_adr_i(arb_adr_o),
      .wbm_dat_i(arb_dat_o),
      .wbm_dat_o(arb_dat_i),
      .wbm_we_i (arb_we_o),
      .wbm_sel_i(arb_sel_o),
      .wbm_stb_i(arb_stb_o),
      .wbm_ack_o(arb_ack_i),
      .wbm_err_o(),
      .wbm_rty_o(),
      .wbm_cyc_i(arb_cyc_o),

      // Slave interface 0 (to BaseRAM controller)
      // Address range: 0x8000_0000 ~ 0x803F_FFFF
      .wbs0_addr    (32'h8000_0000),
      .wbs0_addr_msk(32'hFFC0_0000),

      .wbs0_adr_o(wbs0_adr_o),
      .wbs0_dat_i(wbs0_dat_i),
      .wbs0_dat_o(wbs0_dat_o),
      .wbs0_we_o (wbs0_we_o),
      .wbs0_sel_o(wbs0_sel_o),
      .wbs0_stb_o(wbs0_stb_o),
      .wbs0_ack_i(wbs0_ack_i),
      .wbs0_err_i('0),
      .wbs0_rty_i('0),
      .wbs0_cyc_o(wbs0_cyc_o),

      // Slave interface 1 (to ExtRAM controller)
      // Address range: 0x8040_0000 ~ 0x807F_FFFF
      .wbs1_addr    (32'h8040_0000),
      .wbs1_addr_msk(32'hFFC0_0000),

      .wbs1_adr_o(wbs1_adr_o),
      .wbs1_dat_i(wbs1_dat_i),
      .wbs1_dat_o(wbs1_dat_o),
      .wbs1_we_o (wbs1_we_o),
      .wbs1_sel_o(wbs1_sel_o),
      .wbs1_stb_o(wbs1_stb_o),
      .wbs1_ack_i(wbs1_ack_i),
      .wbs1_err_i('0),
      .wbs1_rty_i('0),
      .wbs1_cyc_o(wbs1_cyc_o),

      // Slave interface 2 (to UART controller)
      // Address range: 0x1000_0000 ~ 0x1000_FFFF
      .wbs2_addr    (32'h1000_0000),
      .wbs2_addr_msk(32'hFFFF_0000),

      .wbs2_adr_o(wbs2_adr_o),
      .wbs2_dat_i(wbs2_dat_i),
      .wbs2_dat_o(wbs2_dat_o),
      .wbs2_we_o (wbs2_we_o),
      .wbs2_sel_o(wbs2_sel_o),
      .wbs2_stb_o(wbs2_stb_o),
      .wbs2_ack_i(wbs2_ack_i),
      .wbs2_err_i('0),
      .wbs2_rty_i('0),
      .wbs2_cyc_o(wbs2_cyc_o)
  );

  /* =========== Lab6 MUX end =========== */

  /* =========== Lab6 Arbiter begin =========== */

  logic        wbm0_cyc_o;
  logic        wbm0_stb_o;
  logic        wbm0_ack_i;
  logic [31:0] wbm0_adr_o;
  logic [31:0] wbm0_dat_o;
  logic [31:0] wbm0_dat_i;
  logic [ 3:0] wbm0_sel_o;
  logic        wbm0_we_o;

  logic        wbm1_cyc_o;
  logic        wbm1_stb_o;
  logic        wbm1_ack_i;
  logic [31:0] wbm1_adr_o;
  logic [31:0] wbm1_dat_o;
  logic [31:0] wbm1_dat_i;
  logic [ 3:0] wbm1_sel_o;
  logic        wbm1_we_o;

  wb_arbiter_2 arbiter(
      .clk(sys_clk),
      .rst(sys_rst),

      .wbm0_adr_i(wbm0_adr_o),
      .wbm0_dat_i(wbm0_dat_o),
      .wbm0_dat_o(wbm0_dat_i),
      .wbm0_we_i(wbm0_we_o),
      .wbm0_sel_i(wbm0_sel_o),
      .wbm0_stb_i(wbm0_stb_o),
      .wbm0_ack_o(wbm0_ack_i),
      .wbm0_err_o(),
      .wbm0_rty_o(),
      .wbm0_cyc_i(wbm0_cyc_o),

      .wbm1_adr_i(wbm1_adr_o),
      .wbm1_dat_i(wbm1_dat_o),
      .wbm1_dat_o(wbm1_dat_i),
      .wbm1_we_i(wbm1_we_o),
      .wbm1_sel_i(wbm1_sel_o),
      .wbm1_stb_i(wbm1_stb_o),
      .wbm1_ack_o(wbm1_ack_i),
      .wbm1_err_o(),
      .wbm1_rty_o(),
      .wbm1_cyc_i(wbm1_cyc_o),

      .wbs_adr_o(arb_adr_o),
      .wbs_dat_i(arb_dat_i),
      .wbs_dat_o(arb_dat_o),
      .wbs_we_o(arb_we_o),
      .wbs_sel_o(arb_sel_o),
      .wbs_stb_o(arb_stb_o),
      .wbs_ack_i(arb_ack_i),
      .wbs_err_i('0),
      .wbs_rty_i('0),
      .wbs_cyc_o(arb_cyc_o)
  );

  /* =========== Lab6 Arbiter end =========== */

  /* =========== Lab6 Slaves begin =========== */
  sram_controller #(
      .SRAM_ADDR_WIDTH(20),
      .SRAM_DATA_WIDTH(32)
  ) sram_controller_base (
      .clk_i(sys_clk),
      .rst_i(sys_rst),

      // Wishbone slave (to MUX)
      .wb_cyc_i(wbs0_cyc_o),
      .wb_stb_i(wbs0_stb_o),
      .wb_ack_o(wbs0_ack_i),
      .wb_adr_i(wbs0_adr_o),
      .wb_dat_i(wbs0_dat_o),
      .wb_dat_o(wbs0_dat_i),
      .wb_sel_i(wbs0_sel_o),
      .wb_we_i (wbs0_we_o),

      // To SRAM chip
      .sram_addr(base_ram_addr),
      .sram_data(base_ram_data),
      .sram_ce_n(base_ram_ce_n),
      .sram_oe_n(base_ram_oe_n),
      .sram_we_n(base_ram_we_n),
      .sram_be_n(base_ram_be_n)
  );

  sram_controller #(
    .SRAM_ADDR_WIDTH(20),
    .SRAM_DATA_WIDTH(32)
) sram_controller_ext (
    .clk_i(sys_clk),
    .rst_i(sys_rst),

    // Wishbone slave (to MUX)
    .wb_cyc_i(wbs1_cyc_o),
    .wb_stb_i(wbs1_stb_o),
    .wb_ack_o(wbs1_ack_i),
    .wb_adr_i(wbs1_adr_o),
    .wb_dat_i(wbs1_dat_o),
    .wb_dat_o(wbs1_dat_i),
    .wb_sel_i(wbs1_sel_o),
    .wb_we_i (wbs1_we_o),

    // To SRAM chip
    .sram_addr(ext_ram_addr),
    .sram_data(ext_ram_data),
    .sram_ce_n(ext_ram_ce_n),
    .sram_oe_n(ext_ram_oe_n),
    .sram_we_n(ext_ram_we_n),
    .sram_be_n(ext_ram_be_n)
);

  uart_controller #(
    .CLK_FREQ(10_000_000),
    .BAUD    (115200)
  ) uart_controller (
    .clk_i(sys_clk),
    .rst_i(sys_rst),

    .wb_cyc_i(wbs2_cyc_o),
    .wb_stb_i(wbs2_stb_o),
    .wb_ack_o(wbs2_ack_i),
    .wb_adr_i(wbs2_adr_o),
    .wb_dat_i(wbs2_dat_o),
    .wb_dat_o(wbs2_dat_i),
    .wb_sel_i(wbs2_sel_o),
    .wb_we_i (wbs2_we_o),

    // to UART pins
    .uart_txd_o(txd),
    .uart_rxd_i(rxd)
  );

  /* =========== Lab6 Slaves end =========== */

  /* =========== Lab6 IF ================== */
logic [31:0] pc_ifid_i;
logic [31:0] inst_ifid_i;
logic [31:0] pc_branch;
logic pc_branch_o;
logic pc_stall_i;
logic pc_finish;

  SEG_IF seg_if(
    .clk_i(sys_clk),
    .rst_i(sys_rst),

    .pc_in(pc_branch),
    .pc_out(pc_ifid_i),
    .inst_out(inst_ifid_i),
    .branch_i(pc_branch_o),
    .stall_i(pc_stall_i),
    .pc_finish(pc_finish),

    .wbm0_adr_o(wbm0_adr_o),
    .wbm0_dat_o(wbm0_dat_o),
    .wbm0_dat_i(wbm0_dat_i),
    .wbm0_we_o(wbm0_we_o),
    .wbm0_sel_o(wbm0_sel_o),
    .wbm0_stb_o(wbm0_stb_o),
    .wbm0_ack_i(wbm0_ack_i),
    .wbm0_err_i('0),
    .wbm0_rty_i('0),
    .wbm0_cyc_o(wbm0_cyc_o)
  );
  /* =========== Lab6 IF end ============== */

    /* =========== Lab6 ID ================== */
logic [31:0] pc_ifid_o;
logic [31:0] inst_ifid_o;
logic [31:0] a_idexe_i;
logic [31:0] b_idexe_i;
logic [31:0] pc_idexe_i;
logic [31:0] inst_idexe_i;
logic a_confict;
logic b_confict;
logic [31:0] a_in;
logic [31:0] b_in;

  SEG_ID seg_id(
    .clk_i(sys_clk),
    .rst_i(sys_rst),

    .inst_in(inst_ifid_o),
    .pc_in(pc_ifid_o),
    .a_out(a_idexe_i),
    .b_out(b_idexe_i),
    .a_conflict(a_confict),
    .b_conflict(b_confict),
    .a_in(a_in),
    .b_in(b_in),
    .pc_out(pc_idexe_i),
    .inst_out(inst_idexe_i),
    .rf_raddr_a(raddr_a),
    .rf_raddr_b(raddr_b),
    .rf_rdata_a(rdata_a),
    .rf_rdata_b(rdata_b),
    .csrindex(csrindex),
    .csrreg(csrreg)
  );
  /* =========== Lab6 ID end ============== */

  /* =========== Lab6 EXE ================== */
logic [31:0] a_idexe_o;
logic [31:0] b_idexe_o;
logic [31:0] pc_idexe_o;
logic [31:0] inst_idexe_o;
logic [31:0] alu_exemem_i;
logic [31:0] b_exemem_i;
logic [31:0] pc_exemem_i;
logic [31:0] inst_exemem_i;

  SEG_EXE seg_exe(
    .inst_in(inst_idexe_o),
    .pc_in(pc_idexe_o),
    .rdata_a(a_idexe_o),
    .rdata_b(b_idexe_o),
    .alu_out(alu_exemem_i),
    .raddr_out(b_exemem_i),
    .pc_out(pc_exemem_i),
    .inst_out(inst_exemem_i),
    .pc_branch(pc_branch),
    .branch_o(pc_branch_o),
    .alu_op(alu_op),
    .alu_a(alu_a),
    .alu_b(alu_b),
    .alu_y(alu_y),
    .waddr_csr(csrindex_2),
    .wdata_csr(csr_wdata),
    .we_csr(rf_we_csr)
  );
  /* =========== Lab6 EXE end ============== */

  /* =========== Lab6 MEM ================== */
  logic [31:0] alu_exemem_o;
  logic [31:0] b_exemem_o;
  logic [31:0] pc_exemem_o;
  logic [31:0] inst_exemem_o;
  logic [31:0] data_memwb_i;
  logic [31:0] inst_memwb_i;
  logic [5:0] load_rd2;
  logic data_ack_o;

  SEG_MEM seg_mem(
      .clk_i(sys_clk),
      .rst_i(sys_rst),

      .inst_in(inst_exemem_o),
      .pc_in(pc_exemem_o),
      .alu_in(alu_exemem_o),
      .raddr_in(b_exemem_o),
      .data_out(data_memwb_i),
      .inst_out(inst_memwb_i),
      .data_ack_o(data_ack_o),
      .load_rd(load_rd2),

      .wbm1_adr_o(wbm1_adr_o),
      .wbm1_dat_o(wbm1_dat_o),
      .wbm1_dat_i(wbm1_dat_i),
      .wbm1_we_o(wbm1_we_o),
      .wbm1_sel_o(wbm1_sel_o),
      .wbm1_stb_o(wbm1_stb_o),
      .wbm1_ack_i(wbm1_ack_i),
      .wbm1_err_i('0),
      .wbm1_rty_i('0),
      .wbm1_cyc_o(wbm1_cyc_o)
    );
    /* =========== Lab6 MEM end ============== */


    /* =========== Lab6 WB ================== */
    logic [31:0] data_memwb_o;
    logic [31:0] inst_memwb_o;

    SEG_WB seg_wb(
      .data_in(data_memwb_o),
      .inst_in(inst_memwb_o),
      .rf_waddr(rf_waddr),
      .rf_wdata(rf_wdata),
      .rf_we(rf_we)
    );
    /* =========== Lab6 WB end ============== */

    /* =========== Lab6 REGS ===============*/

    logic [5:0] idexe_rs1;
    logic [5:0] idexe_rs2;
    logic [5:0] exemem_rd;
    logic [5:0] memwb_rd;
    logic pc_stall;
    logic ifid_stall;
    logic ifid_bubble;
    logic idexe_stall;
    logic idexe_bubble;
    logic exemem_stall;
    logic exemem_bubble;
    logic memwb_stall;
    logic memwb_bubble;

  REG_IFID reg_ifid(
    .clk_i(sys_clk),
    .rst_i(sys_rst),

    .pc_in(pc_ifid_i),
    .pc_out(pc_ifid_o),
    .inst_in(inst_ifid_i),
    .inst_out(inst_ifid_o),
    .stall_i(ifid_stall),
    .bubble_i(ifid_bubble),
    .pc_finish(pc_finish)
  );

  REG_IDEXE reg_idexe(
    .clk_i(sys_clk),
    .rst_i(sys_rst),

    .pc_in(pc_idexe_i),
    .pc_out(pc_idexe_o),
    .inst_in(inst_idexe_i),
    .inst_out(inst_idexe_o),
    .a_in(a_idexe_i),
    .a_out(a_idexe_o),
    .b_in(b_idexe_i),
    .b_out(b_idexe_o),
    .idexe_rs1(idexe_rs1),
    .idexe_rs2(idexe_rs2),
    .load_rd2(load_rd2),
    .if_stall_o(pc_stall),
    .stall_i(idexe_stall),
    .bubble_i(idexe_bubble),
    .pc_finish(pc_finish)
  );

  REG_EXEMEM reg_exemem(
    .clk_i(sys_clk),
    .rst_i(sys_rst),

    .pc_in(pc_exemem_i),
    .pc_out(pc_exemem_o),
    .inst_in(inst_exemem_i),
    .inst_out(inst_exemem_o),
    .alu_in(alu_exemem_i),
    .alu_out(alu_exemem_o),
    .b_in(b_exemem_i),
    .b_out(b_exemem_o),
    .exemem_rd(exemem_rd),
    .stall_i(exemem_stall),
    .bubble_i(exemem_bubble),
    .pc_finish(pc_finish)
  );

  REG_MEMWB reg_memwb(
    .clk_i(sys_clk),
    .rst_i(sys_rst),

    .data_in(data_memwb_i),
    .data_out(data_memwb_o),
    .inst_in(inst_memwb_i),
    .inst_out(inst_memwb_o),
    .memwb_rd(memwb_rd),
    .stall_i(memwb_stall),
    .bubble_i(memwb_bubble),
    .pc_finish(pc_finish)

  );

/* =========== Lab6 REGS end ===============*/

/* =========== Lab6 Confict ================*/

  ID_confict confict(
    .idexe_rs1(idexe_rs1),
    .idexe_rs2(idexe_rs2),
    .exemem_rd(exemem_rd),
    .memwb_rd(memwb_rd),
    .conflict_rs1(a_confict),
    .conflict_rs2(b_confict),
    .rs1_out(a_in),
    .rs2_out(b_in),
    .exemem_in(alu_exemem_i),
    .memwb_in(data_memwb_i)
  );
/* =========== Lab6 Confict end================*/

/* =========== Lab6 controller ================*/
  conflict_controller conflict_controller(
    .branch_conflict_i(pc_branch_o),
    .data_ack_i(data_ack_o),
    .pc_stall_i(pc_stall),
    .pc_ack_o(pc_stall_i),
    .ifid_stall_o(ifid_stall),
    .ifid_bubble_o(ifid_bubble),
    .idexe_stall_o(idexe_stall),
    .idexe_bubble_o(idexe_bubble),
    .exemem_stall_o(exemem_stall),
    .exemem_bubble_o(exemem_bubble),
    .memwb_stall_o(memwb_stall),
    .memwb_bubble_o(memwb_bubble)
  );
/* =========== Lab6 controller end ================*/
endmodule
