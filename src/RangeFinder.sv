`default_nettype none

// Module Description:
// This module implements a hardware thread that determines the range
// between the maximum and minimum values of a series of input numbers. 
// It uses a finite state machine (FSM) to manage the tracking of inputs 
// and error handling.
module RangeFinder
#(parameter WIDTH=8)
  (input  logic [WIDTH-1:0] data_in,
   input  logic clock, reset,
   input  logic go, finish,
   output logic [WIDTH-1:0] range,
   output logic error);

  typedef enum logic [1:0] {IDLE, ACTIVE, ERROR_STATE} state_t;
  state_t state, next_state;

  logic [WIDTH-1:0] min_value, max_value;

  // Detect rising edge of go
  logic go_prev;
  logic go_edge;
  always_ff @(posedge clock, posedge reset) begin
    if (reset) go_prev <= 1'b0;
    else go_prev <= go;
  end
  assign go_edge = go & ~go_prev;

  // sequential logic
  always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
      state <= IDLE;
      min_value <= {WIDTH{1'b1}};
      max_value <= '0;
      range <= '0;
      error <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          if (go_edge && !finish) begin
            // start new sequence
            min_value <= data_in;
            max_value <= data_in;
          end
        end

        ACTIVE: begin
          // Track min/max every cycle
          logic [WIDTH-1:0] min_temp, max_temp;
          min_temp = (data_in < min_value) ? data_in : min_value;
          max_temp = (data_in > max_value) ? data_in : max_value;

          min_value <= min_temp;
          max_value <= max_temp;

          // Compute range on finish edge
          if (finish)
            range <= max_temp - min_temp;
        end

        ERROR_STATE: begin
          // do nothing, stay latched
        end
      endcase

      // Latch/clear error
      if (next_state == ERROR_STATE)
        error <= 1'b1;
      else if (state == ERROR_STATE && next_state == ACTIVE)
        error <= 1'b0;
    end
  end

  // FSM transitions (using go_edge instead of go)
  always_comb begin
    next_state = state;

    unique case (state)
      IDLE: begin
        // simultaneous on rising edge
        if (go_edge && finish) next_state = ERROR_STATE; 
        else if (finish) next_state = ERROR_STATE; // finish before start
        else if (go_edge) next_state = ACTIVE;
      end

      ACTIVE: begin
        // second rising edge before finish
        if (go_edge) next_state = ERROR_STATE; 
        else if (finish) next_state = IDLE;
      end

      ERROR_STATE: begin
        if (go_edge && !finish) next_state = ACTIVE; // recover on new start
        else next_state = ERROR_STATE;
      end
    endcase
  end

endmodule: RangeFinder
