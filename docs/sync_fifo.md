Interface: 

| Ports      | Dir      | Width    | Info      |
| ---------- | -------- | -------- | --------- |
| clk, rst_n | in       | 1        | synchronous low reset |
| s_valid, s_ready, s_data | in, out, in | 1, 1, WIDTH | Write side (data goes into the FIFO) |
| m_valid, m_ready, m_data | out, in, out | 1, 1, WIDTH | Read side (data goes out the FIFO)  |
| count | out | $clog2(DEPTH)+1 | current occupancy |

**Parameters:**
- Width = 64bits
- Depth = 16
Depth is power 2 so no wrap around logic is needed for pointers

**Full/Empty Ambiguity**
Fixed by the count register:
- count == 0 ? empty 
- count == DEPTH ? full
Intuitive solution

Could be fixed by adding one extra bit to the pointer registers. If right bits and extra bit is equal : full, else empty.
- Less hardware cost

**Distributed RAM for asynchronous read**
