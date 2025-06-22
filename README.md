# Mesa Freedreno/Turnip Driver Builder

Simple Bash script that aims to build a turnip driver for **Magisk/KernelSU** or **emulators**.

## Build instructions

Ensure you have the following commands available in your system:

* `meson`
* `ninja`
* `patchelf`
* `unzip`
* `curl`
* `flex`
* `bison` (**NOTE**: Bison should be version 2.4 or later, check with `bison --version`. MacOS by default has old Bison 2.3 version, so install newer with `brew install bison` and `brew link --force bison`).
* `zip`
* `glslang`
* `pip` or `pip3`. This script install some Python packages globally by default. If you dont want this behavior, you can execute script from Poetry virtual environment to install packages locally (see below).

If your system does not allow to install system-wide Python packages (e. g. Python installed via Homebrew), or you want to install them locally, the build script should be executed from _virtualenv_. It can be done using [Poetry](https://python-poetry.org/). Install poetry on your system, then do the following from the project root:

```bash
poetry install
eval "$(poetry env activate)"
```

To start build process just type

```
./build-turnip.sh build
```

You can also specify custom options for the build script (for example, custom Android NDK). To see all availabe options type the following:

```
./build-turnip.sh help
```


# Credits

### This software is based on the amazing work of the following developers:
 
 **[@v3kt0r-87](//github.com/v3kt0r-87)** for creating the original [Mesa-Turnip-Builder](//github.com/v3kt0r-87/Mesa-Turnip-Builder) script.

 **[@MrMiy4mo](//github.com/ilhan-athn7)** for creating the [freedreno_turnip-CI](https://github.com/ilhan-athn7/freedreno_turnip-CI) script.
 
 **[@Mesa3D Team](//gitlab.freedesktop.org/mesa/mesa)** for creating an open source drivers for Adreno.

 **[Adreno Driver Support Group](//t.me/adreno_driver)** for testing and sharing benchmarks.

