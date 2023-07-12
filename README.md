# Synchronizing CPU and GPU Work (Swift Conversion)

## Source
https://developer.apple.com/documentation/metal/resource_synchronization/synchronizing_cpu_and_gpu_work

## Test scenario
The number of triangles has been increased to ```3_000_000``` for testing on an M1 Macbook air.

To see how the semaphore can impact rendering, change the number of Semaphores between 1 and 3.
You will notice that at 1 the fps are under 24, while with 3 it runs at 40. One can visually see how the race conditions can cause the GPU from updating.

## Disclaimer
I am still pretty new to Swift and have been trying to find better and more efficient ways of interacting with Data at the memory level especially for GPU accessibility.

This is all a learning excersise, so others can find more up to date examples of Swift and Apple code.

If you have any suggestion on updating this repo please feel free to create a pull request or submit a bug for feedback.
