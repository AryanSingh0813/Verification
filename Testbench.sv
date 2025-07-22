`timescale 1ns / 1ps

class transaction;
   rand bit oper;//Randomized bit for operation control (1 or 0)
   bit rd, wr;
   bit [7:0] data_in;
   bit full, empty;
   bit [7:0] data_out;
   
   constraint oper_ctrl{
    oper dist {1 :/ 50, 0 :/ 50};
   }
   
endclass

class generator;
   
   transaction tr;
   mailbox #(transaction) mbx;
   int count = 0;  // Number of transactions to generate
   int i = 0;// Iteration counter
   
   event next;
   event done;
   
   function new(mailbox #(transaction)mbx);
    this.mbx = mbx;
    tr = new();
   endfunction
   
   task run();
    repeat(count) begin
        assert(tr.randomize) else $error("Randomization Failed");
        i++;
        mbx.put(tr);
        $display("[GEN] : Oper : %0d \t iteration : %0d", tr.oper, i);
        @(next);
    end
    ->done;
   endtask
    
endclass

class driver;
    virtual fifo_if fif;
    mailbox #(transaction) mbx;
    transaction datac;
    
    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction
    
    task reset();
        fif.rst <= 1'b1;
        fif.rd <= 1'b0;
        fif.wr <= 1'b0;
        fif.data_in <= 0;
        repeat(5)@(posedge fif.clk);
        fif.rst <= 1'b0;
        $display("[DRV]: DUT Reset Done");
        $display("-------------------------------------------------------------------------");
    endtask
    
    task write();
        @(posedge fif.clk);
        fif.rst <= 1'b0;
        fif.rd <= 1'b0;
        fif.wr <= 1'b1;
        fif.data_in <= $urandom_range(1,10);
        @(posedge fif.clk);
        fif.wr <= 1'b0;
        $display("[DRV]: DATA WRITE \t data : %0d", fif.data_in);
    endtask
    
    task read();
    @(posedge fif.clk);
    fif.rst <= 1'b0;
    fif.rd <= 1'b1;
    fif.wr <= 1'b0;
    @(posedge fif.clk);
      fif.rd <= 1'b0;
    $display("[DRV] : Data Read");
    @(posedge fif.clk);
    endtask
    
    task run();
        forever begin
            mbx.get(datac);
            if(datac.oper == 1'b1) write();
            else read();
        end
    endtask
    
endclass

class monitor;
   virtual fifo_if fif;
   mailbox #(transaction) mbx;
   transaction tr;
   
   function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
   endfunction
   
   task run();
    tr = new();
    
    forever begin
        repeat(2)@(posedge fif.clk);
        tr.wr = fif.wr;
        tr.rd = fif.rd;
        tr.data_in = fif.data_in;
        tr.full = fif.full;
        tr.empty = fif.empty;
        @(posedge fif.clk);
        tr.data_out = fif.data_out;
        
        mbx.put(tr);
        $display("[MON] : Wr:%0d \t Rd : %0d \t din : %0d\t dout : %0d \t full : %0d \t empty : %0d", tr.wr, tr.rd, tr.data_in,
            tr.data_out, tr.full, tr.empty);
    end
    
   endtask
   
endclass

class scoreboard;
    mailbox #(transaction)mbx;
    transaction tr;
    event next;
    
    bit [7:0]din[$];//queue to stroe data
    bit [7:0] temp;
    int err;
    
    function new(mailbox #(transaction)mbx);
        this.mbx = mbx;
    endfunction
    
    task run();
        forever begin
            mbx.get(tr);
             $display("[SCO] : Wr:%0d rd:%0d din:%0d dout:%0d full:%0d empty:%0d", tr.wr, tr.rd, tr.data_in, tr.data_out, tr.full, tr.empty);
             if(tr.wr == 1'b1)begin
                if(tr.full == 1'b0)begin
                    din.push_front(tr.data_in);
                    $display("[SCO]: DATA STORED IN QUEUE : %0d", tr.data_in);
                end
                else $display("[SCO]: FIFO IS FULL");
             end
             $display("-------------------------------------");
             
             if(tr.rd == 1'b1)begin
                if(tr.empty == 1'b0)begin
                    temp = din.pop_back();
                    if(tr.data_out == temp) $display("[SCO]: Data Match");
                    else begin
                     $error("Data Mismatch");
                     err++;
                    end
                end    
                else $display("[SCO]: FIFO Empty");
                $display("------------------------------------");   
             end
             ->next;
        end
    endtask
    
endclass

class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;
    
    mailbox #(transaction) gdmbx;
    mailbox #(transaction)  msmbx;
    
    event nextgs;
    virtual fifo_if fif;
    
    function new(virtual fifo_if fif);
        gdmbx = new();
        
        gen = new(gdmbx);
        drv = new(gdmbx);
        
        msmbx = new();
        
        mon = new(msmbx);
        sco = new(msmbx);
        
        this.fif = fif;
        drv.fif = this.fif;
        mon.fif = this.fif;
        
        gen.next = nextgs;
        sco.next = nextgs;
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
        $display("--------------------------------------------");
        $display("Error count : %0d", sco.err);
         $display("-------------------------------------------");
         $finish();
    endtask
    
    task run();
        pre_test();
        test();
        post_test();
    endtask
    
endclass

module tb;
  
  fifo_if fif();
  
  fifo_top dut(.clk(fif.clk), .rst(fif.rst), .wr(fif.wr), .rd(fif.rd), .din(fif.data_in), .dout(fif.data_out), .empty(fif.empty), .full(fif.full));
    
    initial begin
        fif.clk <= 0; 
    end
    
    always #10 fif.clk <= ~fif.clk;
    
    environment env;
    
    initial begin
        env = new(fif);
        env.gen.count = 10;
        env.run();
    end
    
endmodule