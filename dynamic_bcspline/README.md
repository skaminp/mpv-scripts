# dynamic_bcspline.lua

## Instructions

### Required

None

### Recommended

The recommended `mpv.conf` options for this script are as follows.

```
correct-downscaling
linear-downscaling
linear-upscaling
sigmoid-upscaling=no

cscale=bilinear
```

These are overridden but are also recommended to be changed.

```
scale=bcspline
scale-param1=1
scale-param2=0
dscale=bcspline
dscale-param1=1
dscale-param2=0
```

Options can be changed through `dynamic_bcspline.conf`. Using the configuration file is optional.