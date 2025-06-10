To create SRAM cells
```
make
```


```
verilator -Wall --lint-only -top-module fiber *.v
iverilog -g2005-sv -s fiber *.v
```

```
verilator -Wall --lint-only -top-module fiber *.v results/*/*.v
iverilog -g2005-sv -s fiber *.v results/*/*.v
```