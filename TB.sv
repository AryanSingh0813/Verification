`timescale 1ns / 1ps
// Code your testbench here
// or browse Examples
// Code your testbench here
// or browse Examples
class transaction;
  
  rand bit newd;
  rand bit [11:0]din;
  bit mosi, cs;
  
  function transaction copy();
    copy = new();
    copy.newd = this.newd;
    copy.din = this.din;
    copy.mosi = this.mosi;
    copy.cs = this.cs;
  endfunction
  
  function void display(input string tag);
    $display("[%0s] :Newd: %0b \t CS:%0b \t Din:%0d \t MOSI:%0b",tag, newd, cs, din, mosi);
  endfunction
  
endclass

class generator;
  
  transaction tr;
  mailbox #(transaction)mbx;
  int count = 0;
  
  event done;
  event drvnext;
  event sconext;
  
  function new(mailbox #(transaction)mbx);
    this.mbx = mbx;
    tr = new();
  endfunction
  
  task run();
    
    repeat(count)begin
      assert(tr.randomize) else $display("Randomization Failed");
      mbx.put(tr.copy);
      tr.display("GEN");
      @(drvnext);
      @(sconext);
    end
    ->done;
  endtask
  
endclass

class driver;
  
 virtual spi_if vif;
 transaction tr;
  mailbox #(transaction) mbx; 
  mailbox #(bit [11:0]) mbxds;
  
  function new(mailbox #(bit [11:0]) mbxds, mailbox #(transaction)mbx);
    
    this.mbx = mbx;
    this.mbxds = mbxds;
  endfunction
  
  event drvnext;
  
  bit [11:0]din;
  
  task reset();
    vif.rst <= 1'b1;
    vif.newd <= 1'b0;
    vif.cs <= 1'b1;
    vif.mosi <= 1'b0;
    //vif.din <= 12'b0;
     vif.din <= 1'b0;
    
    repeat(10)@(posedge vif.clk);
       vif.rst <= 1'b0;
    repeat(5)@(posedge vif.clk);
    
    $display("---------------------------");
    $display("Reset Done");
    
  endtask
  
  task run();
    forever begin
      mbx.get(tr);
      @(posedge vif.sclk);
      vif.newd <= 1'b1;
      vif.din <= tr.din;
      mbxds.put(tr.din);
      @(posedge vif.sclk);
      vif.newd <= 1'b0;
      wait(vif.cs == 1'b1);
      $display("Data Sent: %0d", tr.din);
      ->drvnext;
    end
  endtask
  
endclass

class monitor;
  
  transaction tr;
  mailbox #(bit [11:0])mbx;
  bit [11:0]srx;
  
  virtual spi_if vif;
  
  function new(mailbox #(bit [11:0])mbx);
  	this.mbx = mbx;
  endfunction
  
  task run();
    forever begin
      @(posedge vif.clk);
      wait(vif.cs == 1'b0);////transaction begin
      @(posedge vif.sclk);
      
      for(int i = 0; i <12; i++)begin
        @(posedge vif.sclk);
        srx[i] = vif.mosi;
      end
      
      wait(vif.cs == 1'b1);//transaction end
      
      $display("[MON]: Data Sent: %0d",srx);
      mbx.put(srx);
      
    end
  endtask
  
endclass

class scoreboard;
  
  mailbox #(bit [11:0]) mbxds, mbxms;
  bit [11:0] ds;//data from driver;
  bit [11:0] ms;//data from monitor;
  event sconext;
  
  function new(mailbox #(bit [11:0]) mbxds, mailbox #(bit [11:0])mbxms);
    this.mbxds = mbxds;
    this.mbxms = mbxms;
  endfunction
  
  task run();
    forever begin
      mbxds.get(ds);
      mbxms.get(ms);
      
      $display("[SCO]: DRV : %0d \t MON : %0d", ds, ms);
      
      if(ds == ms) $display(
        "[SCO]: DATA MATCH"
      );
      
      else $display(
        "[SCO]: DATA MISMATCH"
      );
      $display("----------------------------------------");
      ->sconext;
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
  mailbox #(bit [11:0]) mbxds;
  mailbox #(bit [11:0]) mbxms;
  
  virtual spi_if vif;
  
  function new(virtual spi_if vif);
    mbxgd = new();
    mbxms = new();
    mbxds = new();
    gen = new(mbxgd);
    drv = new(mbxds, mbxgd);
    
    mon = new(mbxms);
    sco = new(mbxds, mbxms);
    
    this.vif = vif;
    drv.vif = this.vif;
    mon.vif = this.vif;
    
    gen.sconext = nextgs;
    sco.sconext = nextgs;
    
    gen.drvnext = nextgd;
    drv.drvnext = nextgd;
    
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

module tb;
  spi_if vif();
  spi dut(.clk(vif.clk), .rst(vif.rst), .din(vif.din), .sclk(vif.sclk), .cs(vif.cs), .newd(vif.newd),
          .mosi(vif.mosi));
  
  initial begin
    vif.clk <= 1'b0;
  end
  
  always #10 vif.clk <= ~vif.clk;//check for = instead <=
  
  environment env;
  
  initial begin
    env = new(vif);
    env.gen.count = 20;
    env.run();
    
  end
  
//   initial begin
//    $dumpfile("dump.vcd");
//    $dumpvars;
//  end
  
endmodule

