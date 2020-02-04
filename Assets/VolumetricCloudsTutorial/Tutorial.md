# Tutorial

## Overview & Goal

The goal of this tutorial is to render clouds as a volume of transparent media
within the atmosphere. The focus is on achieving a reasonable lighting, shape,
density, and real-time evolution of the clouds in an artist-controllable
fashion, not attempting an exact simulation.

For simplicity, we will limit our implementation to one where the clouds are
always the furthest semitransparent object rendered. Additionally, we will not
model atmospheric scattering effects of light passing from the clouds to the
camera.

## Prerequisites

TODO

## Project Set-Up

### Image Effects

We set up our Clouds rendering as a Unity Image Effect Component on the Camera
GameObject. See the [Image Effects page](ImageEffects/ImageEffects.md) for more
details.

This will allow our implementation to work across versions of Unity as old as
5.6. It can serve as a good starting point for use as a step in a scriptable
render pipeline, whether Universal, HDRP, or custom.

For similar compatibility reasons, we will keep our work within the Assets
folder. With the appropriate Assembly Definition Files and manifest, it could be
converted to the Unity Package Manager format.

### Noise Textures

## Components

TODO
