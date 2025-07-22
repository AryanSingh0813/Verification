`timescale 1ns / 1ps
module spi_master(
  input clk, rst, newd,
  input [11:0]din,
  output reg sclk, mosi, cs
  
);

  int countc = 0;
  int count = 0;
  
  always@(posedge clk)begin
    if(rst == 1'b1)begin countc <= 0;sclk <= 1'b0;end
    else if(countc < 11) countc <= countc + 1;
    else begin
      countc <= 0;
      sclk <= ~sclk;
    end
  end
  
  typedef enum bit[1:0]{idle = 2'b00, send = 2'b01}state_type;
  state_type state = idle;
  
  reg [11:0] temp;
  
  always@(posedge sclk)begin
    
    if(rst == 1'b1)begin
      mosi <= 1'b0;
      cs <= 1'b1;
    end
    
    else begin
      case(state)
        idle:begin
          if(newd == 1'b1)begin
            state <= send;
            cs <= 1'b0;
            temp <= din;
          end
          else begin
            state <= idle;
           // cs <= 1'b1;
            temp <= 12'h00;
          end
          
        end//idle
        
        send:begin
          if(count < 12)begin
            count <= count + 1;
            mosi <= temp[count];
            end
            else begin
              count <= 0;
              state <= idle;
              cs <= 1'b1;
              mosi <= 1'b0;
            end
        end//send
        default: state <= idle;
      endcase
    end
    
  end
  
endmodule

module spi_slave(
	input sclk, cs, mosi,
  	output reg done,
  output [11:0]dout 
);
  
  int count = 0;
  reg [11:0]temp = 12'h00;
  
  typedef enum bit{ready = 1'b0, read = 1'b1}state_type;
  state_type state = ready;
  
  always@(posedge sclk)begin
    case(state)
      ready:begin
        done <= 1'b0;
        if(cs == 1'b0) state <= read;
        else state <= ready;
      end
      
      read:begin
        if(count <12)begin
          count <= count + 1;
          temp <= {mosi, temp[11:1]};
        end
        else begin count <=0; done <= 1'b1; state <= ready; end
      end
    endcase
  end
  
  assign dout = temp;
  
endmodule
        
module spi_top(
	input clk, rst, newd,
  	input [11:0]din,
  output [11:0] dout,
  output done
);
  wire mosi, sclk, cs;
  
  spi_master m(.clk(clk), .rst(rst), .din(din), .newd(newd), .cs(cs), .mosi(mosi),
              .sclk(sclk));
  spi_slave s(.sclk(sclk), .cs(cs), .mosi(mosi), .done(done), .dout(dout));
endmodule