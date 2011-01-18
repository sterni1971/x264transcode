#!/usr/bin/python

############################################################################
#    DVD/CD Transcoding set of scripts (x264transcode)                     #
#    Copyright (C) 2008-2009 by Jaroslaw Zachwieja <grok@zyxxyz.eu>        #
#                                                                          #
#    This program is free software; you can redistribute it and/or modify  #
#    it under the terms of the GNU General Public License as published by  #
#    the Free Software Foundation; either version 3 of the License, or     #
#    (at your option) any later version.                                   #
#                                                                          #
#    This program is distributed in the hope that it will be useful,       #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#    GNU General Public License for more details.                          #
#                                                                          #
#    You should have received a copy of the GNU General Public License     #
#    along with this program.  If not, see <http://www.gnu.org/licenses/>. #
############################################################################

global DeviceName, AddAction, RemoveAction
AddAction1 = '/sbin/ripper'
AddAction2 = '/sbin/crippler'

import dbus # needed to do anything
import gobject # needed to loop & monitor
import os

def add_device1(*args, **keywords):
        for arg in args:
                if str(arg) == "dbus.Array([dbus.Struct((dbus.String(u'storage.removable.media_available'), dbus.Boolean(False), dbus.Boolean(False)), signature=None)], signature=dbus.Signature('(sbb)'))":
                        os.system(AddAction1)

def add_device2(*args, **keywords):
        for arg in args:
                if str(arg) == "dbus.Array([dbus.Struct((dbus.String(u'storage.removable.media_available'), dbus.Boolean(False), dbus.Boolean(False)), signature=None)], signature=dbus.Signature('(sbb)'))":
                        os.system(AddAction2)


# necessary to connect to bus
from dbus.mainloop.glib import DBusGMainLoop
DBusGMainLoop(set_as_default=True)

bus = dbus.SystemBus()  # connect to system bus
hal_manager_obj1 = bus.get_object('org.freedesktop.Hal', '/org/freedesktop/Hal/devices/storage_model_SONY____CD_RW__CRX320E')
hal_manager_obj2 = bus.get_object('org.freedesktop.Hal', '/org/freedesktop/Hal/devices/storage_model_LG_CD_ROM_CRD_8484B')
hal_manager1 = dbus.Interface(hal_manager_obj1, 'org.freedesktop.Hal.Device')
hal_manager2 = dbus.Interface(hal_manager_obj2, 'org.freedesktop.Hal.Device')

# add listeners for all devices being added or removed
bus.add_signal_receiver(add_device1, 'PropertyModified', 'org.freedesktop.Hal.Device', 'org.freedesktop.Hal', '/org/freedesktop/Hal/devices/storage_model_SONY____CD_RW__CRX320E')
bus.add_signal_receiver(add_device2, 'PropertyModified', 'org.freedesktop.Hal.Device', 'org.freedesktop.Hal', '/org/freedesktop/Hal/devices/storage_model_LG_CD_ROM_CRD_8484B')

# monitor
loop = gobject.MainLoop()
loop.run()