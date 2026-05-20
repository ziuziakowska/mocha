# Images

## Mocha Architecture Diagram

If you need to make changes to the Mocha architecture diagram in Inkscape, make sure to
export the image as a plain .svg by going to `File > Export`. If saved by just pressing
`ctrl-s`, Inkscape will populate the file with session specific information.

To re-generate the paths-only version of the diagram, select all objects with `ctrl-a`,
then use `Path > Object to Path`. Export the file using the same steps as above.

## D2 language

This image is automatically generated.

The Mocha block diagram is written using [the D2 language](https://d2lang.com/).

You can regenerate this using the following command:
```sh
d2 --watch mocha.d2
```
