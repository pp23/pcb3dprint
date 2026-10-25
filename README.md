# PCB exposure with UVtools

> This project was created with help from Grok, built by xAI.

Headless converter from KiCad Gerber and Excellon files to an Anycubic Photon Mono 4 `.pm4n` file. UVtools does not invent printer geometry. It overwrites a real sliced template that already contains the LCD size and pixel pitch, then draws the board into that file.

Tested against UVtools 7.1.0.

## What you need

- Docker
- A real Photon Mono 4 slice, used only as a template. Any small print exported from Photon Workshop as `.pm4n` is enough. Copy it per job. The operation overwrites the input file.
- KiCad Gerbers for the copper layer you want to expose, the board outline, and the drill file

`UVtoolsCmd convert` cannot turn a Gerber into `.pm4n`. The path is `run … PCBExposure` on an existing slicer file.

## Build

```bash
docker build -t uvtools:7.1.0 -f uvtoolscmd.dockerfile .
```

The image is Ubuntu 24.04 plus the official `UVtools_linux-x64` package. `libcvextern.so` needs the OpenCV runtime libraries, including `libatlas3-base` (`libcblas.so.3`). The entrypoint is `UVtoolsCmd`.

Check the build:

```bash
docker run --rm uvtools:7.1.0 --version
```

## Run

Mount the directory that holds the template and the Gerbers. Paths inside `-p FileArray=` are paths inside the container.

```bash
docker run --rm -v "$PWD":/work -w /work uvtools:7.1.0 \
  run Board.pm4n PCBExposure -?
```

`-?` prints the live parameter list for that UVtools version. Prefer that over this README if they disagree.

## Export from KiCad

In PCB Editor: **File → Fabrication Outputs → Gerbers (.gbr)**.

Plot these layers, Gerber format, millimetres:

| Layer | Why |
| --- | --- |
| `B.Cu` or `F.Cu` | The copper you actually expose. One side per file. |
| `Edge.Cuts` | Board outline. Used for placement margins, not exposed. |

Then **Generate Drill Files**. Excellon, same units and origin as the Gerbers, absolute origin. Keep plated and non-plated holes as the files KiCad writes (`.drl`, and `-NPTH.drl` if present). Pass every drill file you want punched out of the pads.

Useful plot settings:

- Check zone fills before plotting, so pours are up to date.
- Leave **Use extended X2 format** on.
- Do not mirror in KiCad. Mirroring is a UVtools parameter, and it must match how the board sits on the LCD.
- Default KiCad names such as `hello_world-Edge_Cuts.gbr` are detected as outlines. A Protel `.gko` name is detected too. A renamed outline is not, unless the filename ends in `Edge_Cuts`, `Edge-Cuts`, `Edge.Cuts`, `Outline`, `Profile`, or the extension is `.gko`.

Accepted artwork extensions are `.gbr`, `.gtl`, `.gbl`, `.gts`, `.gbs`, `.gto`, `.gbo`, `.gml`, `.drl`, and `.xln`.

## Generate the .pm4n

Copy the template first. `PCBExposure` replaces its layers.

```bash
cp PhotonMono4-template.pm4n Board.pm4n

docker run --rm -v "$PWD":/work -w /work uvtools:7.1.0 \
  run Board.pm4n PCBExposure \
  -p FileArray=hello_world-B_Cu.gbr \
  -p FileArray=hello_world-PTH.drl \
  -p FileArray=hello_world-Edge_Cuts.gbr \
  -p MergeFiles=true \
  -p InvertColor=true \
  -p Mirror=true \
  -p ExposureTime=120
```

Repeat `-p FileArray=` once per input file. With an `Edge.Cuts` file, the default anchor `TopLeft` keeps the physical margin from the outline to the copper. The outline itself is not drawn into the exposure.

Bottom copper (`B.Cu`) is usually mirrored, because that side faces the LCD. Top copper usually is not. Confirm with a paper or scrap exposure before committing a board. `ExposureTime` is seconds and depends on the film, lamp age, and whether you are exposing dry film or a solder-mask process. `120` is only a starting value.

`InvertColor=true` lights the copper (or the openings, depending on the film) instead of the background. `InvertArea` defaults to `BoardOutline`, so only the inside of the outline is inverted and the rest of the plate stays dark. `InvertArea=Plate` lights the whole LCD outside the artwork. Do not use that for a normal board.

Other parameters worth knowing:

| Parameter | Default | Meaning |
| --- | --- | --- |
| `MergeFiles` | `false` | One layer containing every artwork file. Without it, each file becomes its own layer. |
| `Anchor` | `TopLeft` | Placement on the plate. `TopLeft` needs an outline. `MiddleCenter` and `None` do not. |
| `OffsetX`, `OffsetY` | `0` | Extra shift in millimetres after anchoring. |
| `FlipVertically` | `true` | Compensates for Gerber Y-up versus image Y-down. Leave it on unless a viewer check says otherwise. |
| `LayerHeight` | from the template | Layer thickness written into the file. Irrelevant to the mask image, relevant to how the printer moves. |
| `EnableAntiAliasing` | `false` | Softens edges. Leave off for a binary mask. |
| `FillPlate` | `false` | Tile whole copies across the LCD. `FillSpacingX` and `FillSpacingY` are the gaps in millimetres. |

If the Gerbers were plotted in page coordinates and land off the plate, the image is blank. Add the outline and keep `TopLeft`, or set `-p Anchor=MiddleCenter`.

`Anchor=None` keeps the coordinates from the files and does not need an outline. That is only correct when the plot origin already matches the plate.

## Optional STL

This is a reconstruction of the exposed pixels, not the KiCad board. It is useful as a preview, not as something to slice again.

```bash
docker run --rm -v "$PWD":/work -w /work uvtools:7.1.0 \
  run Board.pm4n LayerExportMesh -p FilePath=Board.stl
```

`Quality` can be `Accurate` (default), `Average`, `Quick`, `Dirty`, or `Minecraft`. `Quick` is enough to see whether the traces landed on the plate.
