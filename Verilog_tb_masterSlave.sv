`timescale 1ns / 1ps
//module tb_1;
//  reg rst = 0, clk = 0, newd = 0;
//  reg [11:0]din = 0;
//  reg [11:0]dout;
//  wire done;
  

  
//  always #10 clk <= ~clk;
  
//  spi_top dut(.rst(rst), .clk(clk), .newd(newd), .din(din), .dout(dout), .done(done));
  
//  initial begin
//    rst = 1'b1;
//    repeat(10)@(posedge clk);
//    rst = 1'b0;
//    for(int i = 0; i <10; i++)begin
//  	  newd = 1;
//      din = $urandom;
//      @(posedge dut.s.sclk);
//      newd = 0;
//      @(posedge done);
//    end
//  end
  
////  initial begin
////    $dumpfile("dump.vcd");
////    $dumpvars;
////  end
  
//endmodule

class transaction;
  
  rand bit newd;
  rand bit [11:0]din;
  bit [11:0]dout;
  
  function transaction copy();
    copy = new();
   	copy.newd = this.newd;
    copy.din = this.din;
    copy.dout = this.dout;
  endfunction
  
endclass

class generator;
  
  transaction tr;
  mailbox #(transaction) mbx;
  
  event done;
  event drvnxt;
  event sconxt;
  
  int count = 0;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
    tr = new();
  endfunction
  
  task run();
    repeat(count)begin
      assert(tr.randomize) else $display("Randomization Failed");
      mbx.put(tr.copy);
      $display("[GEN] : DIN : %0d", tr.din);
      @(sconxt);
    end
    ->done;
  endtask
  
endclass

class driver;
  
  virtual spi_if vif;
  transaction tr;
  mailbox #(transaction) mbx;
  mailbox #(bit [11:0]) mbxds;
  
  function new(
    mailbox #(transaction) mbx,
  mailbox #(bit [11:0]) mbxds
  );
    this.mbx = mbx;
    this.mbxds = mbxds;
  endfunction
  
   event drvnxt;  
  
  task reset();
    vif.rst <= 1'b1;
    vif.newd <= 1'b0;
    vif.din <= 1'b0;
    
    repeat(10)@(posedge vif.clk);
    	vif.rst <= 1'b0;
    repeat(5)@(posedge vif.clk);
    $display("Reset Done");
    $display("------------------------");
    
  endtask
  
  task run();
    forever begin
  	  mbx.get(tr);
	  vif.newd <= 1'b1;
      vif.din <= tr.din;
      mbxds.put(tr.din);
      @(posedge vif.sclk);
      vif.newd <= 1'b0;
      @(posedge vif.done);
      $display("[DRV] : Data Sent to DUT : %0d", tr.din);
      @(posedge vif.sclk);
    end
  endtask
  
endclass

class monitor;
  
  transaction tr;
  virtual spi_if vif;
  mailbox #(bit [11:0]) mbx;
  
  function new(mailbox #(bit [11:0]) mbx);
    this.mbx = mbx;
  endfunction
  
  task run();
    tr = new();
    forever begin
      @(posedge vif.sclk);
      @(posedge vif.done);
      tr.dout <= vif.dout;
      @(posedge vif.sclk);
      $display("[MON] : Output Data : %0d", tr.dout);
      mbx.put(tr.dout);
    end
  endtask
  
endclass

class scoreboard;
  
  mailbox #(bit [11:0]) mbxds, mbxms;
  
  bit [11:0] ds;
  bit [11:0] ms;
  
  event sconxt;
  
  function new(mailbox #(bit[11:0])mbxds, mailbox #(bit[11:0]) mbxms);

    this.mbxds = mbxds;
    this.mbxms = mbxms;
  
  endfunction
    
    task run();
      forever begin
        
        mbxds.get(ds);
        mbxms.get(ms);
        
        $display("[SCO] : Driver Data : %0d\t Monitor Data :%0d", ds, ms);
        
        if(ds == ms) $display("Data Matched");
        else $display("Data Mismatch");
        
        $display("----------------------------");
        ->sconxt;
        
      end
    endtask
endclass

class environment;
  
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  event nextgd;
  event nextgs;
  
  mailbox #(transaction) mbxgd;
  mailbox #(bit [11:0]) mbxds;//input
  mailbox #(bit [11:0]) mbxms;//ouput
  
  virtual spi_if vif;
  
  function new(virtual spi_if vif);
    
    mbxgd = new();
    mbxds = new();
    mbxms = new();
    
    gen = new(mbxgd);
    drv = new(mbxgd, mbxds);
    mon = new(mbxms);
    sco = new(mbxds, mbxms);
    
    this.vif = vif;
    drv.vif = this.vif;
    mon.vif = this.vif;
    
    gen.sconxt = nextgs;
    sco.sconxt = nextgs;
    
    drv.drvnxt = nextgd;
    gen.drvnxt = nextgd;
    
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered);
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
  
endclass

module tb();
  
  spi_if vif();
  
  spi_top dut(.clk(vif.clk), .rst(vif.rst), .newd(vif.newd),
          .din(vif.din), .dout(vif.dout), .done(vif.done)
         );
  
  initial begin
    vif.clk <= 1'b0;
  end
  
  always #10 vif.clk = ~vif.clk;
  
  environment env;
  
  assign vif.sclk = dut.m.sclk;
  
  initial begin
    env = new(vif);
    env.gen.count = 4;
    env.run();
  end
  
//  initial begin
//    $dumpvars;
//    $dumpfile("dump.vcd");
//  end
  
endmodule

