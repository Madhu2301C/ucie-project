// Separate test-only harness. No production scoreboard or coverage model overrides.
class ucie_coverage_extension_test extends uvm_test;
    `uvm_component_utils(ucie_coverage_extension_test)
    virtual ucie_retry_if r;
    virtual ucie_link_if l;
    ucie_coverage_container env, ra, la;
    ucie_retry_monitor rm;
    ucie_link_monitor lm;
    ucie_coverage cov;
    string scenario;
    int checks;

    function new(string name="ucie_coverage_extension_test", uvm_component parent=null);
        super.new(name,parent);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ucie_retry_if)::get(null,"uvm_test_top.env.retry_agent","vif",r))
            `uvm_fatal("EXT_CONFIG","retry vif missing")
        if (!uvm_config_db#(virtual ucie_link_if)::get(null,"uvm_test_top.env.link_agent","vif",l))
            `uvm_fatal("EXT_CONFIG","link vif missing")
        if (!$value$plusargs("EXT_CASE=%s",scenario)) scenario="RETRY_DEEP";
        env=new("env",this); ra=new("retry_agent",env); la=new("link_agent",env);
        rm=ucie_retry_monitor::type_id::create("monitor",ra);
        lm=ucie_link_monitor::type_id::create("monitor",la);
        cov=ucie_coverage::type_id::create("coverage",env);
    endfunction
    function void connect_phase(uvm_phase phase);
        rm.analysis_port.connect(cov.retry_cov_export);
        lm.analysis_port.connect(cov.link_cov_export);
    endfunction
    function void verify_condition(bit ok,string message);
        checks++;
        if (!ok) `uvm_fatal("EXT_CHECK",message)
    endfunction
    task accept_retry(logic [543:0] expected, bit replay);
        bit accepted;
        accepted=0;
        for(int n=0;n<40;n++) begin
            @(posedge r.clk);
            if(r.tx_valid && r.tx_ready) begin
                verify_condition(r.tx_flit_out===expected,"accepted retry payload mismatch");
                verify_condition(r.retransmit===replay,"retransmit qualification mismatch");
                accepted=1; break;
            end
        end
        verify_condition(accepted,"retry handshake deadline");
        @(negedge r.clk);
        verify_condition(r.busy && !r.tx_valid,"WAIT_ACK expected");
    endtask
    task start_retry(logic [543:0] data, int stalls);
        @(negedge r.clk);
        r.tx_flit=data; r.tx_ready=0; r.send_req=1;
        @(negedge r.clk); r.send_req=0;
        repeat(stalls) begin
            verify_condition(r.tx_valid && r.busy && r.tx_flit_out===data,"initial backpressure stability");
            @(negedge r.clk);
        end
        r.tx_ready=1;
        accept_retry(data,0);
    endtask
    task finish_retry();
        r.ack=1;
        @(negedge r.clk); r.ack=0; r.nak=0;
        verify_condition(!r.busy && !r.tx_valid && !r.timeout_pulse,"ACK must retire pending flit");
    endtask
    task retry_deep();
        logic [543:0] data, expected;
        data={17{32'ha5963cc3}};
        start_retry(data,4);
        // Exercise retained data rather than accidentally comparing live inputs.
        r.tx_flit=~data;
        for(int i=0;i<11;i++) begin
            r.nak=1; r.tx_ready=0;
            @(negedge r.clk); r.nak=0;
            repeat(2) begin
                verify_condition(r.tx_valid && !r.retransmit && r.tx_flit_out===data,"stalled replay stability");
                @(negedge r.clk);
            end
            r.tx_ready=1;
            expected=data;
            if($test$plusargs("EXT_NEGATIVE") && i==0) expected[0]=~expected[0];
            accept_retry(expected,1);
        end
        finish_retry();
        `uvm_info("EXT_COUNTS","retry accepted=12 replay=11 NAK=11 initial_stall=4",UVM_LOW)
    endtask
    task boundary_retry();
        logic [543:0] data;
        int delay_cycles;
        bit use_nak;
        uvm_hdl_data_t count_value;
        delay_cycles=10; void'($value$plusargs("BOUNDARY=%d",delay_cycles));
        use_nak=$test$plusargs("BOUNDARY_NAK");
        data='1;
        start_retry(data,1);
        repeat(delay_cycles) @(negedge r.clk);
        verify_condition(uvm_hdl_read("tb_top.dut.timeout_count",count_value),"read timeout boundary count");
        verify_condition(count_value[3:0]===delay_cycles[3:0],$sformatf("timeout count must equal requested boundary: actual=%0d expected=%0d",count_value[3:0],delay_cycles));
        if(use_nak) r.nak=1; else r.ack=1;
        #1;
        verify_condition(!r.timeout_pulse,"ACK/NAK must suppress timeout at boundary");
        @(negedge r.clk); r.nak=0; r.ack=0;
        if(use_nak) begin
            accept_retry(data,1); finish_retry();
        end else verify_condition(!r.busy,"boundary ACK must return IDLE without replay");
        `uvm_info("EXT_COUNTS",$sformatf("boundary=%0d nak=%0d",delay_cycles,use_nak),UVM_LOW)
    endtask
    task pending_reset();
        int state_select;
        state_select=0; void'($value$plusargs("RESET_STATE=%d",state_select));
        @(negedge r.clk); r.tx_flit='1; r.send_req=1; r.tx_ready=0;
        @(negedge r.clk); r.send_req=0;
        verify_condition(r.busy && r.tx_valid,"reset setup SEND_NEW");
        if(state_select>0) begin
            r.tx_ready=1; accept_retry('1,0);
            if(state_select==2) begin
                r.nak=1; r.tx_ready=0;
                @(negedge r.clk); r.nak=0;
                verify_condition(r.tx_valid && r.busy,"reset setup SEND_REPLAY");
            end
        end
        r.rst_n=0; r.ack=0; r.nak=0;
        #1; verify_condition(!r.busy && !r.tx_valid && r.tx_flit_out==='0,"asynchronous pending reset");
        repeat(2) @(negedge r.clk);
        r.rst_n=1;
        repeat(15) begin
            @(negedge r.clk);
            verify_condition(!r.busy && !r.tx_valid && !r.timeout_pulse,"reset must discard pending transaction");
        end
        `uvm_info("EXT_COUNTS",$sformatf("pending reset state=%0d no ghost replay",state_select),UVM_LOW)
    endtask
    task link_replay();
        int depth, accepted, errors, replays, baseline, pattern;
        logic [511:0] data, expected;
        uvm_hdl_data_t value;
        bit done_seen;
        depth=11; pattern=0;
        void'($value$plusargs("DEPTH=%d",depth));
        void'($value$plusargs("PATTERN=%d",pattern));
        case(pattern)
            0: data={16{32'ha55ac33c}};
            1: data='1;
            2: data='0;
            default: for(int i=0;i<16;i++) data[i*32+:32]=$urandom();
        endcase
        @(negedge l.clk);
        baseline=l.retransmission_count;
        l.payload=data; l.sequence_num=8'hff ^ pattern; l.tx_ready=0;
        l.inject_error=(depth>0); l.send_req=1;
        // Test-only fault extension: rearm the stock one-shot injector.
        // No forcing CRC verdicts, ACK/NAK, counters or received data.
        if(depth>0) verify_condition(uvm_hdl_force("tb_top.link_dut.injected_once",0),"rearm injection force");
        @(negedge l.clk); l.send_req=0;
        // A request presented while busy must not restart the pending flit.
        l.send_req=1;
        repeat(3) begin
            verify_condition(l.tx_valid && l.busy && !l.done,"link initial backpressure / busy request ignored");
            @(negedge l.clk);
        end
        l.send_req=0;
        l.tx_ready=1; accepted=0; errors=0; replays=0; done_seen=0;
        for(int cycle=0;cycle<300;cycle++) begin
            @(posedge l.clk);
            if(l.tx_valid && l.tx_ready) begin
                accepted++; if(l.retransmit) replays++;
                verify_condition(uvm_hdl_read("tb_top.link_dut.rx_crc_error",value),"read CRC result");
                verify_condition(value[0]===(accepted<=depth),"CRC decision for deliberately corrupted/clean transfer");
                if(value[0]) errors++;
                verify_condition(uvm_hdl_read("tb_top.link_dut.header_byte1",value),"read received sequence");
                verify_condition(value[3:0]===l.sequence_num[3:0],"received sequence low nibble mismatch");
                verify_condition(uvm_hdl_read("tb_top.link_dut.header_byte0",value),"read received sequence high nibble");
                verify_condition(value[3:0]===l.sequence_num[7:4],"received sequence high nibble mismatch");
            end
            #2;
            if(l.done) begin done_seen=1; break; end
            @(negedge l.clk);
            if(depth>0 && accepted==depth)
                verify_condition(uvm_hdl_force("tb_top.link_dut.injected_once",1),"stop deliberate injection");
        end
        verify_condition(done_seen,"link completion deadline");
        expected=data;
        if($test$plusargs("EXT_NEGATIVE")) expected[0]=~expected[0];
        verify_condition(l.received_payload===expected,"link recovered payload mismatch");
        verify_condition(accepted==depth+1 && errors==depth && replays==depth,"link exact transfer/error/replay counts");
        verify_condition(l.retransmission_count-baseline==depth,"link cumulative replay delta");
        verify_condition(l.crc_error_seen===(depth>0),"sticky CRC result");
        @(negedge l.clk); @(negedge l.clk);
        verify_condition(!l.busy,"link returned IDLE");
        if(depth>0) verify_condition(uvm_hdl_release("tb_top.link_dut.injected_once"),"release fault injection");
        `uvm_info("EXT_COUNTS",$sformatf("link accepted=%0d CRC_errors=%0d replays=%0d payload/sequence verified",accepted,errors,replays),UVM_LOW)
        // Exercise both toggle directions and verify reset clears completed state.
        l.payload='0; l.sequence_num='0; l.inject_error=0; l.tx_ready=0;
        l.rst_n=0;
        #1;
        verify_condition(!l.done && !l.busy && !l.crc_error_seen &&
                         l.retransmission_count===0 && l.received_payload==='0,
                         "link reset must clear registered transaction results");
        repeat(2) @(negedge l.clk);
        l.rst_n=1;
    endtask
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        wait(r.rst_n && l.rst_n); @(negedge r.clk);
        case(scenario)
            "RETRY_DEEP": retry_deep();
            "BOUNDARY": boundary_retry();
            "RESET": pending_reset();
            "LINK": link_replay();
            default: `uvm_fatal("EXT_CASE","unknown extension scenario")
        endcase
        r.tx_flit='0;
        repeat(3) @(negedge r.clk);
        `uvm_info("EXT_CHECK_PASS",$sformatf("%s checks=%0d TEST_DONE",scenario,checks),UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass
