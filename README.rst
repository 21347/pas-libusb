pas-libusb -- Object Oriented wrapper for LibUSB
================================================

`libusb <https://libusb.info/>`_ and its fork `libusbx
<http://libusbx.sourceforge.net/>`_ provide access to USB devices in user
space.

This project provides Pascal header translations plus an object-oriented
wrapper for convenience.

Note: In the current branch only the legacy version 0.1 of libusb is
supported.  The new version 1.0 introduced major changes in the API and is
supported in branch "libusb-1.0".

License
-------

    Copyright (C) 2012 Johann Glaser <Johann.Glaser@gmx.at>

    This program is free software; you can redistribute it and/or modify  
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or  
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

Each file contains a header showing the according license.

 - libusb(x) and its header translation are licensed under LGPL 2.1 (or later).
 - Some C preprocessor macros were translated to Pascal functions. These are
   licensed under a modified LGPL.
 - All other Pascal units (especially the OOP wrapper) are licensed under a
   modified LGPL which allows static linking (see the file
   COPYING.modifiedLGPL.txt).
 - The example programs are released as public domain so you can base
   commercial work on them.


Directory Structure
-------------------

  ``src/``
    Header translations and OOP wrapper.

  ``src/examples/``
    Example for the direct usage of the OOP wrapper. This directory also has a
    ``Makefile``.

Build
-----

::

  $ cd src/examples/
  $ make

For further information see the comment at the top of `src/examples/testfirmware.pas
<pas-libusb/blob/master/src/examples/testfirmware.pas>`_.

Usage
-----

Simply add the units ``LibUSB`` and ``USB`` to the uses-clause of your
program. Derive from the class ``TUSBDevice`` to implement your custom driver.

The unit ``EZUSB`` provdes the class ``TUSBDeviceEZUSB`` to interface to the
Cypress EZ-USB AN2131 microcontrollers. It provides functions to access the
on-chip SRAM and to download its firmware.

Platform
--------

This project was compiled with `FreePascal <http://www.freepascal.org/>`_
2.6.0 on Linux.

The main work was performed on a Debian GNU/Linux AMD64 machine with
libusb-1.0 version 1.0.12.

A user successfully used pas-libusb on a Raspberry Pi (ARM processor) with
the Raspbian Debian GNU/Linux based distribution. Although the libusb-1.0
package version 1.0.9 originally installed didn't work (due to lacking the
two functions libusb_get_port_number() and libusb_get_port_path()), he
manually upgraded from libusbx sources to version 1.0.14 which now works.
The same user also reports libusb-1.0 1.0.12 on Linux Mint i386 to work.

Other Projects
--------------

**k7103-usb**
  The USB Interface of the Velleman k7103 PC Storage Oscilloscope
  http://k7103.sourceforge.net/ uses these units to communicate with the
  hardware.

**EZ-Tools**
  EZ-Tools is a command line tool for generic access to devices with a built
  in Cypress EZ-USB AN2131 microcontroller.
