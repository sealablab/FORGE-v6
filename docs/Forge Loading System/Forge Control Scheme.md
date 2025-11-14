# [Forge Control Scheme](Forge Control Scheme.md)

The FORGE control scheme uses 3 bits in Control Register 0 for safe initialization:

```
CR0[31] = forge_ready   ← Set by loader after deployment
CR0[30] = user_enable   ← User control (GUI toggle)
CR0[29] = clk_enable    ← Clock gating control
```


**All four conditions must be met** for the module to operate:
```vhdl
global_enable = forge_ready AND user_enable AND clk_enable AND loader_done
```

This ensures modules are disabled on power-on and only start when fully initialized.

This aspect of the FORGE platform is addressed inside [README](../../sys/forge-platform/README.md)
