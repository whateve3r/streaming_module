`timescale 1ns/100ps

module tb_top;

  import axi4stream_vip_pkg::*;   // базовый пакет VIP
  import axis_vip_mst_pkg::*;     // пакет сгенерированного master-IP
  import axis_vip_slv_pkg::*;     // пакет сгенерированного slave-IP

  logic aclk    = 1'b0;
  logic aresetn = 1'b0;
  logic rst;                      

  always #5 aclk = ~aclk;         
  assign rst = ~aresetn;          

  logic [7:0] x_data,  thr_data,  y_data;
  logic       x_valid, thr_valid, y_valid;
  logic       x_ready, thr_ready, y_ready;


  axis_vip_mst x_vip (
    .aclk         (aclk),
    .aresetn      (aresetn),
    .m_axis_tvalid(x_valid),
    .m_axis_tready(x_ready),
    .m_axis_tdata (x_data)
  );

  axis_vip_mst thr_vip (
    .aclk         (aclk),
    .aresetn      (aresetn),
    .m_axis_tvalid(thr_valid),
    .m_axis_tready(thr_ready),
    .m_axis_tdata (thr_data)
  );

  axis_vip_slv y_vip (
    .aclk         (aclk),
    .aresetn      (aresetn),
    .s_axis_tvalid(y_valid),
    .s_axis_tready(y_ready),
    .s_axis_tdata (y_data)
  );


  top dut (
    .clk      (aclk),
    .rst      (rst),
    .x_data   (x_data),
    .x_valid  (x_valid),
    .thr_data (thr_data),
    .thr_valid(thr_valid),
    .y_ready  (y_ready),
    .x_ready  (x_ready),
    .thr_ready(thr_ready),
    .y_data   (y_data),
    .y_valid  (y_valid)
  );

  axis_vip_mst_mst_t x_agent;
  axis_vip_mst_mst_t thr_agent;
  axis_vip_slv_slv_t y_agent;

  logic [7:0] x_q  [$];
  logic [7:0] thr_q[$];

  localparam int NDIR  = 5;                // проверка на равенство или переполнение
  localparam int NRAND = 195;              // случайные значения
  localparam int N     = NDIR + NRAND;

  logic [7:0] dir_x  [NDIR] = '{8'd255, 8'd0,   8'd100, 8'd200, 8'd128};
  logic [7:0] dir_thr[NDIR] = '{8'd0,   8'd255, 8'd100, 8'd50,  8'd128};

  int sent_x  = 0, sent_thr = 0, checked = 0, errors = 0;

// эталонная функция, с ней сравниваем
  function automatic logic [7:0] model(input logic [7:0] x,
                                       input logic [7:0] thr);
    if (x > thr) return (x * 2);   
    else         return (x + 1);  
  endfunction

  task automatic send_value(axis_vip_mst_mst_t agent, input logic [7:0] value);
    axi4stream_transaction   tr;
    xil_axi4stream_data_beat beat;      // массив байт
    tr = agent.driver.create_transaction("mst tr");
    assert (tr.randomize());            // рандомизация задержек/выравнивания
    beat = '{default:8'h00};
    beat[0] = value;                    // канал 1-байтный -> байт [0]
    tr.set_data_beat(beat);             // фиксируем tdata
    agent.driver.send(tr);
  endtask

  //  Основной тест
  initial begin
    // создаём агентов, привязываясь к интерфейсам внутри VIP
    x_agent   = new("x_agent",   x_vip.inst.IF);
    thr_agent = new("thr_agent", thr_vip.inst.IF);
    y_agent   = new("y_agent",   y_vip.inst.IF);

    aresetn = 1'b0;
    repeat (10) @(posedge aclk);
    aresetn = 1'b1;
    repeat (2)  @(posedge aclk);

    // запуск агентов
    x_agent.start_master();
    thr_agent.start_master();
    y_agent.start_slave();

    // генератор случайного y_ready
    begin
      axi4stream_ready_gen rgen;
      rgen = y_agent.driver.create_ready("y_rgen");
      rgen.set_ready_policy(XIL_AXI4STREAM_READY_GEN_RANDOM);
      rgen.set_low_time_range (0, 5);   // сколько тактов y_ready держится в 0
      rgen.set_high_time_range(1, 5);   // сколько тактов y_ready держится в 1
      y_agent.driver.send_tready(rgen);
    end

    fork
      begin
        for (int k = 0; k < NDIR; k++) begin
          x_q.push_back(dir_x[k]);
          send_value(x_agent, dir_x[k]);
          sent_x++;
        end
        for (int k = 0; k < NRAND; k++) begin
          logic [7:0] v = $urandom;
          x_q.push_back(v);
          send_value(x_agent, v);
          sent_x++;
        end
      end

      begin
        for (int k = 0; k < NDIR; k++) begin
          thr_q.push_back(dir_thr[k]);
          send_value(thr_agent, dir_thr[k]);
          sent_thr++;
        end
        for (int k = 0; k < NRAND; k++) begin
          logic [7:0] v = $urandom;
          thr_q.push_back(v);
          send_value(thr_agent, v);
          sent_thr++;
        end
      end

      // проверка выхода y
      begin
        axi4stream_monitor_transaction m;
        xil_axi4stream_data_beat       rbeat;
        logic [7:0] got, exp, xv, tv;
        for (int i = 0; i < N; i++) begin
          y_agent.monitor.item_collected_port.get(m);
          rbeat = m.get_data_beat();
          got   = rbeat[0];

          wait (x_q.size() > 0 && thr_q.size() > 0); // защита от чтения нуля
          xv  = x_q.pop_front();
          tv  = thr_q.pop_front();
          exp = model(xv, tv);
          checked++;

          if (got !== exp) begin
            errors++;
            $error("[%0t] MISMATCH #%0d: x=%0d thr=%0d -> got=%0d exp=%0d",
                    $time, checked, xv, tv, got, exp);
          end
          else begin
            $display("[%0t] OK #%0d: x=%0d thr=%0d -> y=%0d",
                      $time, checked, xv, tv, got);
          end
        end
      end
    join

    repeat (20) @(posedge aclk);

    $display("=====================================================");
    $display(" Sent X=%0d  THR=%0d  Checked=%0d  Errors=%0d",
              sent_x, sent_thr, checked, errors);
    if (errors == 0) $display(" TEST PASSED");
    else             $display(" TEST FAILED");
    $display("=====================================================");
    $finish;
  end

 
// здесь обрабатывается случай если вдруг поток завис из за неправильной работы модуля. симуляция намеренно завершается по истечении времени (оно заведомо больше чем длительность всех транзакций)
  initial begin
    #2_000_000;
    $display("[%0t] HANG. checked=%0d out of %0d",
              $time, checked, N);
    $finish;
  end

endmodule