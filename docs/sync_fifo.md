Interface: 

| Ports      | Dir      | Width    | Info      |
| ---------- | -------- | -------- | --------- |
| clk, rst_n | in       | 1        | synchronous low reset |
| s_valid, s_ready, s_data | in, out, in | 1, 1, WIDTH | Write side (data goes into the FIFO) |
| m_valid, m_ready, m_data | out, in, out | 1, 1, WIDTH | Read side (data goes out the FIFO)  |
| count | out | $clog2(DEPTH)+1 | current occupancy |

Parameter:
- Width = 64bits
- Depth = 16