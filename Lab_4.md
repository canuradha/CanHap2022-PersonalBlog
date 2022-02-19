---
layout: default
title: "Lab 4 - P's, I's and D's with Haply"
permalink: /Lab_4/
---
# Lab 4 - The P's, I's and D's with Haply
18th Feb 2022

---
In the latest lab we were tasked to used control the actuation of Haply using a PID controller. (In case for anyone who
doesn't know what PID stands for, in simple terms it's a closed loop feedback controlling method which uses the
**P**roportional, **I**ntegral and **D**erivative terms of the error). For this lab we were given a skeleton code (which
also included a GUI) that can be used to tune the PID values for our Haplys. The assignment was to play with the three
main parameters (i.e.: P, I and D) and set up a stable system.

## Controlling P
First I rand the code and started increasing P since the smallest increment possible for P was 0.01, I started with
that. Even though there was a response when the location of the object was changed the accuracy seems much less (Fig. 1).
Increasing the P seems to add much more force to the End effector when the object location is changed but when it passes
a certain limit (P > 0.3) this seems to make the tracking of the object much harder (the feedback makes the End
effector move further than necessary and sometimes instead of stopping at the target continuous oscillation of the end
effector tends to occur). The maximum P value that could be obtained without losing the stability seems to
be 0.2 (Fig. 2). So I chose P=0.3 as the unstable condition (for starting the Derivative adjustments)

| ![P01](assets/P-0.1.gif) | ![P02n](assets/P-0.2.gif) |
| Figure 1 | Figure 2 |


When P=0.3:
<iframe src="https://drive.google.com/file/d/142xQWLfIJqa8uTQxbAIGUXkqJvPsFLiA/preview" width="640" height="480" allow="autoplay"></iframe>

## Controlling D
With P set to 0.3 I started incrementing the Derivative parameter. Even though it was possible to increase D with 0.01
increments since there was no apparent changes with smaller increments I decided to go with 0.5 increments. This largely
reduced the problems I had with the increased P value but similar to before, excessive increasing of the D value tends
to make the tracking unstable. I found the best value (with P=0.3) around 1.0 mark. Figure 3 and 4 shows the motion of
when D=0.5 and D= 1.0.

| ![P03D05](assets/P-0.3, D-0.5.gif) | ![P03D1](assets/P-0.3, D-1.0.gif) |
| Figure 3 | Figure 4 |

The video shows the motion when D=1.5 (P=0.3 for all the scenarios)

<iframe src="https://drive.google.com/file/d/1cWpNuphUBaVNFvyGBGXKkypxRdLFO640/preview" width="640" height="480" allow="autoplay"></iframe>

With *D = 1.5* the system almost, always reach the target, but sometimes it was observed that there could be a minor
difference between the target and the end effector location (0.13s on the video).

## Controlling I
So for further refinement I started to change the *I* value with 0.01 increments (while keeping P=0.3 and D = 1.5).
Since feedback from the *I* value tends to compounded with every iteration if there's a non-zero error and to avoid any
problems that could result from excess feedback in the beginning, every time the application was restarted, I first
moved the end effector to the target starting location, adjusted the P and D values (to be 0.3 and 1.5 respectively),
reset the integrator (using the button on the GUI) and started incrementing the integrator. The best stability was found
when I = 0.2

<iframe src="https://drive.google.com/file/d/13N_Ok8LF6VH9vTpLbrtl0Dqg5T5dMLyt/preview" width="640" height="480" allow="autoplay"></iframe>

## Path tracking
Next I tested the accuracy of automatic path tracking with the found values for PID. For this I edited the code so that
the target traverses in a square path. But with the current P, D and I values, the end effector started to show higher
oscillations while traversing the path. The highest stability was obtained when the D value is set to around 0.8 while P
increased to 1.0 (p=1.0, D=0.8 and I =0.3)

<iframe src="https://drive.google.com/file/d/1kPNqaDZEee-vcDzYrHyzH1WD7Ha6_m-7/preview" width="640" height="480" allow="autoplay"></iframe>

This seems to have the best stability even when the handle motion was restricted for a time. 

<iframe src="https://drive.google.com/file/d/1MkAvK8mlus5LjePBKZ_F7CBM14-RdJK2/preview" width="640" height="480" allow="autoplay"></iframe>

I also tested changing the sampling rate (while keeping the P, D and I values same as before). While increasing the
sampling rate (i.e.: decreasing the frequency) seems to make the motion smoother, the GUI tends to lag when the sampling
rate is changed below 100Hz and when sampling rate was decreased ( i.e.: increasing the frequency) the hand motion tends to
be unstable (frequency above 750Hz)

<iframe src="https://drive.google.com/file/d/1Q_DRGLkWTbcHcHz1Kl5ccUWyBaExwzY8/preview" width="640" height="480" allow="autoplay"></iframe>

Even if the best Sampling rate was found to be between 250Hz and 750Hz. When randomly varying sampling rate was
introduced (Sampling rate randomly changes with every iteration) the system seems to work on 100-1000Hz range as well
(although sometimes there was a slight lag visible). 

<iframe src="https://drive.google.com/file/d/1VwhwkXsWNEuSwGqOOrv-ckB8YDx8silK/preview" width="640" height="480" allow="autoplay"></iframe>

The complete code for the implementation can be found [here](https://github.com/canuradha/CanHap2022-PersonalBlog/tree/haply_pid)