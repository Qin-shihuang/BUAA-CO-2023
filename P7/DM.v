`include "Defines.v"

`define Begin_DM 32'h00000000
`define End_DM   32'h00002fff
`define Begin_TC0 32'h00007f00
`define End_TC0   32'h00007f0b
`define Begin_TC1 32'h00007f10
`define End_TC1   32'h00007f1b
`define Begin_Pr  32'h00007f20
`define End_Pr    32'h00007f23

module DM(
    input wire req,
    input wire RE,
    input wire Exc_Ov_DM,
    output wire Exc_AdEL,
    output wire Exc_AdES,

    input wire [31:0] PC,
    input wire [31:0] Addr,
    input wire WE,
    input wire [2:0] Align,

    input wire [31:0] WD,
    input wire [31:0] m_data_rdata,
    output wire [31:0] m_data_addr,
    output reg [31:0] m_data_wdata,
    output reg [3:0] m_data_byteen,
    output wire [31:0] m_inst_addr,
    output reg [31:0] RD
);
    assign m_data_addr = Addr;
    assign m_inst_addr = PC;

    wire _word, _half, _byte;
    wire _h0, _h1, _b0, _b1, _b2, _b3;

    assign _word = (Align == `DM_align_word);
    assign _half = (Align == `DM_align_half);
    assign _byte = (Align == `DM_align_byte);

    assign _h0 = (Addr[1] == 0) & (Addr[0] == 0);
    assign _h1 = (Addr[1] == 1) & (Addr[0] == 0);

    assign _b0 = (Addr[1] == 0) & (Addr[0] == 0);
    assign _b1 = (Addr[1] == 0) & (Addr[0] == 1);
    assign _b2 = (Addr[1] == 1) & (Addr[0] == 0);
    assign _b3 = (Addr[1] == 1) & (Addr[0] == 1);


    wire AlignError = (Align == `DM_align_word) & (Addr[1:0] != 0) ||
                     (Align == `DM_align_half) & (Addr[0] != 0);
    wire RangeError = !(
        (`Begin_DM <= Addr) & (Addr <= `End_DM) ||
        (`Begin_TC0 <= Addr) & (Addr <= `End_TC0) ||
        (`Begin_TC1 <= Addr) & (Addr <= `End_TC1) ||
        (`Begin_Pr <= Addr) & (Addr <= `End_Pr)
    );
    wire TimerAlignError = (Addr >= `Begin_TC0) && (Align != `DM_align_word);
    wire TimerSaveError  = (Addr == 32'h00007f08) || (Addr == 32'h00007f18);
   // READ 
    assign Exc_AdEL = (RE) & (AlignError || RangeError || TimerAlignError || Exc_Ov_DM);
    assign Exc_AdES = (WE) & (AlignError || RangeError || TimerAlignError || TimerSaveError || Exc_Ov_DM);
    
    always @(*) begin
        if (_word) begin
            RD = m_data_rdata;
        end else if (_half) begin
            if (_h0) begin
                RD = {{16{m_data_rdata[15]}},m_data_rdata[15:0]};
            end else if (_h1) begin
                RD = {{16{m_data_rdata[31]}},m_data_rdata[31:16]};
            end
        end else if (_byte) begin
            if (_b0) begin
                RD = {{24{m_data_rdata[7]}},m_data_rdata[7:0]};
            end else if (_b1) begin
                RD = {{24{m_data_rdata[15]}},m_data_rdata[15:8]};
            end else if (_b2) begin
                RD = {{24{m_data_rdata[23]}},m_data_rdata[23:16]};
            end else if (_b3) begin
                RD = {{24{m_data_rdata[31]}},m_data_rdata[31:24]};
            end
        end
    end

    always @(*) begin
        if (!WE || req) begin
            m_data_byteen = 4'b0000;
        end else begin
            if (_word) begin
                m_data_byteen = 4'b1111;
                m_data_wdata = WD;
            end else if (_half) begin
                if (_h0) begin
                    m_data_byteen = 4'b0011;
                    m_data_wdata[15:0] = WD[15:0];
                end else if (_h1) begin
                    m_data_byteen = 4'b1100;
                    m_data_wdata[31:16] = WD[15:0];
                end 
            end else if (_byte) begin
                if (_b0) begin
                    m_data_byteen = 4'b0001;
                    m_data_wdata[7:0] = WD[7:0];
                end else if (_b1) begin
                    m_data_byteen = 4'b0010;
                    m_data_wdata[15:8] = WD[7:0];
                end else if (_b2) begin
                    m_data_byteen = 4'b0100;
                    m_data_wdata[23:16] = WD[7:0];
                end else if (_b3) begin
                    m_data_byteen = 4'b1000;
                    m_data_wdata[31:24] = WD[7:0];
                end
            end else begin
                m_data_byteen = 4'b0000;
            end
        end
    end
endmodule