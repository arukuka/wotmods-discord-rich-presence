import threading

import BigWorld
from gui.battle_control import avatar_getter
from gui.impl import backport
from gui.impl.gen import R
from helpers import i18n
import pprint

_ARENA_TYPE_EXT_FORMAT = '#menu:loading/battleTypes/{0}'

g_engine = None
run_callbacks_thread = None
event = threading.Event()

def run_callbacks():
    global g_engine
    while not event.wait(timeout=0.1):
        g_engine.run_callbacks()


def common_process_arena():
    arenaType = BigWorld.player().arena.arenaType
    arenaGuiType = BigWorld.player().arenaGuiType
    arenaName = R.strings.arenas.num(arenaType.geometryName).dyn('name')()
    gameplayName = R.strings.arenas.type.dyn(arenaType.gameplayName).dyn('name')()
    vehicleDesc = avatar_getter.getVehicleTypeDescriptor()

    arenaName = backport.text(arenaName)
    gameplayName = backport.text(gameplayName)
    from gui.battle_results.components.common import _ARENA_TYPE_EXT_FORMAT
    arenaGuiName = i18n.makeString(_ARENA_TYPE_EXT_FORMAT.format(arenaGuiType))
    vehicleName = vehicleDesc.type.userString if vehicleDesc is not None else 'None'

    info = dict()
    info['#arenaName']    = arenaName
    info['#gameplayName'] = gameplayName
    info['#arenaGuiName'] = arenaGuiName
    info['#vehicleName']  = vehicleName

    return info

class Engine:
    def __init__(self):
        import xfw_loader.python as loader
        xfwnative = loader.get_mod_module('com.modxvm.xfw.native')
        print(xfwnative.unpack_native('arukuka.discord_rich_presence'))
        self.__native = xfwnative.load_native('arukuka.discord_rich_presence', 'engine.pyd', 'engine')
        self.__native.init_engine()


    def __onArenaPeriodChange(self, period, *_):
        print('__onArenaPeriodChange', period, _)
        if self.__native is None:
            return

        from constants import ARENA_PERIOD
        if period not in [ARENA_PERIOD.WAITING, ARENA_PERIOD.PREBATTLE, ARENA_PERIOD.BATTLE]:
            return

        activity = self.__native.Activity()

        info = common_process_arena()
        pprint.pprint(info)

        import time
        if period == ARENA_PERIOD.WAITING:
            activity.state = backport.text(R.strings.ingame_gui.timer.waiting())
            activity.timestamps.start = int(time.time())
        elif period == ARENA_PERIOD.PREBATTLE:
            activity.state = 'Wating to start'
            remain = BigWorld.player().arena.periodEndTime - BigWorld.serverTime()
            activity.timestamps.end = int(time.time() + remain)
        elif period == ARENA_PERIOD.BATTLE:
            remain = BigWorld.player().arena.periodEndTime - BigWorld.serverTime()
            elapsed = BigWorld.player().arena.periodLength - remain
            activity.timestamps.start = int(time.time() - elapsed)

        activity.details = '{#arenaGuiName} | {#arenaName} | {#gameplayName} | {#vehicleName}'.format(**info)
        activity.get_ref_activity_assets().large_image = 'icon'
        self.__native.update_activity(activity)


    def run_callbacks(self):
        if self.__native is not None:
            self.__native.run_callbacks()


    def register_events(self):
        from PlayerEvents import g_playerEvents
        g_playerEvents.onArenaPeriodChange += self.__onArenaPeriodChange


def init():
    try:
        global g_engine
        g_engine = Engine()

        global run_callbacks_thread
        run_callbacks_thread = threading.Thread(target=run_callbacks)
        run_callbacks_thread.start()

        g_engine.register_events()
    except:
        import traceback
        traceback.print_exc()


def fini():
    global event
    event.set()

    global run_callbacks_thread
    if run_callbacks_thread is not None:
        run_callbacks_thread.join()

