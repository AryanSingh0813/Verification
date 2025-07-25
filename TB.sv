`timescale 1ns / 1ps

class transaction;
  
  typedef enum bit{write = 1'b0, read = 1'b1}oper_type;
  randc oper_type oper;
  
  bit newd;
  rand bit [7:0]din;
  
  bit rx;
  bit tx;
  bit [7:0]dout;
  bit donetx;
  bit donerx;
  
  function transaction copy();
    copy = new();
    copy.newd = this.newd;
    copy.din = this.din;
    copy.rx = this.rx;
    copy.tx = this.tx;
    copy.dout = this.dout;
    copy.donetx = this.donetx;
    copy.donerx = this.rx;
    copy.oper = this.oper;
  endfunction
  
endclass

class generator;
  
  transaction tr;
  mailbox #(transaction) mbx;
  
  event done;
  event drvnext;
  event sconext;
  
  int count = 0;
  
  function new(mailbox #(transaction)mbx);
    this.mbx = mbx;
    tr = new();
  endfunction
  
  task run();
    repeat(count)begin
    assert(tr.randomize) else $error("[DRV] : Randomization Failed");
      mbx.put(tr.copy);
      $display("[GEN] : DIN : %0d \t Operation :%0s", tr.din, tr.oper.name());
      @(drvnext);
      @(sconext);
    end
    ->done;
  endtask
  
endclass

class driver;
  
  transaction tr;
  virtual uart_if vif;
  
  mailbox #(transaction)mbx;
  mailbox #(bit [7:0])mbxds;
  
  event drvnext;
  bit [7:0] dinT;
  
  bit wr = 0;
  bit [7:0] datarx;
  
  function new(mailbox #(transaction)mbx,  mailbox #(bit [7:0])mbxds);
    this.mbx = mbx;
    this.mbxds = mbxds;
  endfunction
  
  task reset();
    vif.rst <= 1'b1;
    vif.din <= 0;
    vif.newd <= 0;
    vif.rx <= 1'b1;
    repeat(5)@(posedge vif.uclktx);
    vif.rst <= 1'b0;
    @(posedge vif.uclktx);
    $display("[DRV] : Reset Completed");
    $display("-----------------------");
  endtask
  
  task run();
    forever begin
      mbx.get(tr);
      
      if(tr.oper == 1'b0)begin
        @(posedge vif.uclktx);
        vif.rst <= 1'b0;
        vif.newd <= 1'b1;
        vif.rx <= 1'b1;//Transmission has stopped
        vif.din <= tr.din;
        @(posedge vif.uclktx);
        vif.newd <= 1'b0;
        
        mbxds.put(tr.din);
        
        $display("[DRV] : Data Sent : %0d", tr.din);
        wait(vif.donetx == 1'b1);
        ->drvnext;
        
      end
      
      else if(tr.oper == 1'b1)begin
        
        @(posedge vif.uclkrx);
        vif.rst <= 1'b0;
        vif.rx <= 1'b0;//Transmission Begins
        vif.newd <= 1'b0;
        @(posedge vif.uclkrx);
        for(int i = 0; i < 8; i++)begin
          @(posedge vif.uclkrx);
          vif.rx <= $urandom;
          datarx[i] = vif.rx;
        end
        
        mbxds.put(datarx);
        $display("[DRV] : Data RCVD : %0d", datarx);
        wait(vif.donerx == 1'b1);
        vif.rx <= 1'b1;
        ->drvnext;
      end
      
    end
  endtask
  
endclass

class monitor;
  
  transaction tr;
  
  mailbox #(bit [7:0])mbx;
  
  bit [7:0] srx;//send
  bit [7:0] rrx;//rcv
  
  virtual uart_if vif;
  
  function new(mailbox #(bit [7:0])mbx);
    this.mbx = mbx;
  endfunction
  
  task run();
    forever begin
      
      @(posedge vif.uclktx);
      if((vif.newd == 1'b1)&&(vif.rx == 1'b1))begin
        @(posedge vif.uclktx);///starts collecting tx data
        for(int i = 0; i < 8; i++)begin
          @(posedge vif.uclktx)
          srx[i] = vif.tx;
        end
        $display("[MON] : Data Send on TX = %0d", srx);
        @(posedge vif.uclktx);
        mbx.put(srx);
      end//if
      
      else if((vif.rx == 1'b0)&&(vif.newd == 1'b0))begin
        wait(vif.donerx == 1);
        rrx = vif.dout;
        $display("[MON] : Data RCVD RX = %0d", rrx);
        @(posedge vif.uclktx);
        mbx.put(rrx);
      end//elseif
      
    end//forever
  endtask
  
endclass

class scoreboard;
  mailbox #(bit [7:0]) mbxds, mbxms;
  
  bit [7:0] ds;
  bit [7:0] ms;
  
  event sconext;
  
  function new(mailbox #(bit [7:0])mbxds, mailbox #(bit [7:0])mbxms);
    this.mbxds = mbxds;
    this.mbxms = mbxms;
  endfunction
  
  task run();
    forever begin
      mbxds.get(ds);
      mbxms.get(ms);
      
      $display("[SCO] : DRV : %0d \t MON : %0d", ds, ms);
      if(ds == ms) $display("Data Matched");
      else $display("Data Mismatched");
      $display("-------------------------------");
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
  
  mailbox #(transaction)mbxgd;
  mailbox #(bit [7:0]) mbxds;
  mailbox #(bit [7:0]) mbxms;
  
  virtual uart_if vif;
  
  function new(virtual uart_if vif);
    
    mbxgd = new();
    mbxms = new();
    mbxds = new();
    
    gen = new(mbxgd);
    drv = new(mbxgd, mbxds);
    
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
  uart_if vif();
  
  uart_top #(100000, 9600)dut
  (
    .clk(vif.clk), .rst(vif.rst), .newd(vif.newd), .rx(vif.rx), .din(vif.din),
    .tx(vif.tx), .dout(vif.dout), .donetx(vif.donetx), .donerx(vif.donerx)
  );
  
  initial begin
    vif.clk = 1'b0;
  end
  
  always #10 vif.clk <= ~vif.clk;
  
  environment env;
  
  initial begin
    env = new(vif);
    env.gen.count = 5;
    env.run();
  end
  
//  initial begin
//    $dumpfile("dump.vcd"); $dumpvars;
//  end
  
  assign vif.uclktx = dut.utx.uclk;
  assign vif.uclkrx = dut.rtx.uclk;  

endmodule