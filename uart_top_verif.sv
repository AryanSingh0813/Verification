`timescale 1ns / 1ps
module uart_tx #(
	parameter clk_freq = 1000000,
  	parameter baud_rate = 9600
)
(
  input newd, rst, clk, 
  input [7:0] tx_data,
  output reg tx,
  output reg done_tx 
  );
  
  localparam clk_count = (clk_freq/baud_rate);
  int countc = 0;
  int countsd = 0;
  
  reg uclk = 0;
  
  always@(posedge clk)begin
    if(countc <= clk_count/2) countc <= countc + 1;
    else begin
      countc <= 0;
      uclk <= ~uclk;
    end
  end
  
  typedef enum logic[1:0]{idle = 2'b00, transfer = 2'b01}state_type;
  state_type state;
  
  reg [11:0]data;
  
  always@(posedge uclk) begin
    if(rst == 1'b1)begin
      //tx <= 1'b1;
      state <= idle;
    end
    else begin
      case(state)
        idle:
          begin
            tx = 1'b1;
            done_tx <= 1'b0;
            countsd <= 0;
            if(newd == 1'b1)begin
             	tx <= 1'b0;
              	data <= tx_data;
              	state <= transfer;
            end
            else begin
              state <= idle;
            end
          end
        transfer:begin
          if(countsd <8)begin
            countsd <= countsd + 1;
            tx <= data[countsd];
            state <= transfer;
          end
          else begin
            countsd <= 0;
            tx <= 1'b1;
            done_tx <= 1'b1;
            state <= idle;
          end
        end
        default : state <= idle;
      endcase
    end
  end
endmodule


module uart_rx #(
  parameter clk_freq = 1000000,
  parameter baud_rate = 9600
)
(
 // input tx;
  input clk, rst,
  input rx,
  output reg done_rx,
  output reg [7:0] rxdata
);
  
  localparam clk_count = (clk_freq/baud_rate);
  
  int countc = 0;
  int countsd = 0;
  
//  reg [7:0] temp;
  reg uclk =0;
  
  always@(posedge clk)begin
    if(countc < clk_count/2) countc <= countc + 1;
    else begin
      countc <= 0;
      uclk <= ~uclk;
    end
  end
  
  enum bit[1:0]{idle = 2'b00, read = 2'b01}state;
  
  always@(posedge uclk)begin
    
    if(rst) begin
      countsd = 0;
      rxdata = 8'h00;
       done_rx = 0;
    end
    else begin
      case(state)
        idle:begin
          rxdata <= 8'h00;	
          countsd <= 0;
          done_rx <= 0;
          if(rx == 1'b0)begin
          	//rx <= 1'b1;
            state <= read;
          end
          else state <= idle;
        end
        read:begin
          if(countsd < 8)begin
            countsd <= countsd + 1;
            rxdata <= {rx, rxdata[7:1]};//right shift operation
           // state <= read;
          end
          else begin
            countsd <= 0;
            done_rx <= 1'b1;
            state <= idle;
          end
        end
        default : state <= idle; 
      endcase
    end
    
  end
//  assign dout = temp;
  
endmodule

module uart_top#(
  parameter clk_freq = 1000000,
  parameter baud_rate = 9600
)
(
  input rst, clk, newd, rx,
  input [7:0] din,
  output tx,
  output [7:0]dout,
  output reg donetx,
  output reg donerx
);  
  
  uart_tx #(clk_freq, baud_rate)
  utx
  (.newd(newd), .rst(rst), .clk(clk), .tx_data(din), .tx(tx), .done_tx(donetx));
  uart_rx #(clk_freq, baud_rate)
  rtx
  (.clk(clk), .rst(rst), .rx(rx), .done_rx(donerx), .rxdata(dout));
  
endmodule

interface uart_if;
  logic rst, clk, newd, rx;
  logic uclktx;
  logic uclkrx;
  logic [7:0] din;
  logic tx;
  logic [7:0]dout;
  logic donetx;
  logic donerx; 
endinterface