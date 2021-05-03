# mpv-scripts
Any mpv scripts I've create that I feel are worth sharing.

## dynamic_bcspline.lua

A flexible filtering option that is especially suited for scaling in linear color space. [Upscaling in linear light is generally recommended against](https://legacy.imagemagick.org/Usage/filter/nicolas/#upsampling_examples), however there are many instances in which one would want to do so.

This isn't a magical upscaling filter—it simply changes sharpness at different zoom levels by dynamically modifying the B-spline (B) and Cardinal (C) parameters exposed through mpv. Sharpness is retained in downscaling and slight upscaling. At larger upscaling increments the image becomes more blurred to counteract stairstepping and oversharpening; especially the more noticeable ringing artifacts from linear upscaling.

### Explanation

B and C have an inverse relationship where `C = 1/2 * -B + 1/2`.

![image](./images/key-filters.png)

You may notice that the lines intersect at `(1/3, 1/3)` which is the same as the Mitchell filter.
https://legacy.imagemagick.org/Usage/filter/#windowed

![Mitchell-Netravali Survey Of Cubic Filters](https://legacy.imagemagick.org/Usage/img_diagrams/cubic_survey.gif)

We can see the relationship represented in the graph as the `Keys filters` line.

Since we have the inverse relationship we can scale B and C according how zoomed in/out the image is. For that we need the ratio of the scaled image divided by the original image  then converted to log base 2. Now we have a nice linearly scaling number that starts at 0 to plug into our formula. Fortunately there's plenty of convenient functions which will give a gradual curve from 0 limited between -1 in the negative direction and 1 in the positive direction.

![](https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Gjl-t%28x%29.svg/1000px-Gjl-t%28x%29.svg.png)

`x/1+|x|` is the easiest to work with as the intersection naturally lands at `(1/2, 1/3)`

![image](./images/key-filters-func.png)

Multiplying our value by 1.5 once again gives us an intersection of `(1/3, 1/3)`.

![image](./images/key-filters-func-mult.png)

This gives us B and C for any zoom value above and below 0. Values below 0 don't necessarily have to be used due to how correct-downscaling works but it's nice to have if more sharpening when downscaling is needed.
