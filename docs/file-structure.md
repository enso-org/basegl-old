# File Structure

## Top Level Overview

- lib
- src
    - data
    - display
    - gui
    - input
    - motion


## Tree
### Core

- data 
    - array
    - color
    - vector
    - texture

- lib
    - event
    - config
    - laziness
    - property
    - reflection
    - unique-object
    - hierarchical-object

- display
    - object
    - symbol
        - 3D
            - geometry
            - attribute (+scope +gpu +gpuRegistry)
            - mesh      (+gpu)
            - material

            - system
                - sprite
                - particle 
        
        - 2D
            - shape
                - shader
            - text
            - image
    - view
        - camera
        - scene
            - viewport
            - world
            - inspector
        - renderer
            - webgl
            - css
        - navigation


### Addons

- motion
- gui
    - component
        - selectionBox
        - slider
        - ...

- input
    - keyboard

