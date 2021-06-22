import threading
import time
import json

import BigWorld
from gui.impl import backport
from gui.impl.gen import R
from helpers import i18n, dependency, getClientLanguage
from skeletons.gui.app_loader import IAppLoader, GuiGlobalSpaceID
from CurrentVehicle import g_currentVehicle
import ResMgr
import pprint

g_engine = None
run_callbacks_thread = None
event = threading.Event()

def run_callbacks():
    global g_engine
    while not event.wait(timeout=1):
        g_engine.run_callbacks()


def read_file(vfs_path):
    print('trying to load {}'.format(vfs_path))
    vfs_file = ResMgr.openSection(vfs_path)
    if vfs_file is not None and ResMgr.isFile(vfs_path):
        print('    success')
        return str(vfs_file.asString)
    else:
        print('    failed: {}'.format(ResMgr.resolveToAbsolutePath(vfs_path)))


    return None


def load_settings():
    DEFAULT_LANGUAGE = 'en'
    SETTINGS_PATH_FORMAT = '../mods/configs/arukuka.discord_rich_presence/{}.json'

    language = getClientLanguage()
    print(language)
    settings_json = read_file(SETTINGS_PATH_FORMAT.format(language))
    if settings_json is None:
        settings_json = read_file(SETTINGS_PATH_FORMAT.format(DEFAULT_LANGUAGE))

    print(type(settings_json), settings_json)
    settings_json = settings_json.encode('utf-8')
    print(type(settings_json), settings_json)
    settings = json.loads(settings_json)

    return settings


class Engine:
    class _STATES:
        UNKNOWN         = 0
        IN_LOBBY        = 1
        IN_QUEUE        = 2
        ARENA_WAITING   = 3
        ARENA_PREBATTLE = 4
        ARENA_BATTLE    = 5

    _STATES_TO_JSON_KEY = {
        _STATES.IN_LOBBY       : 'in_lobby',
        _STATES.IN_QUEUE       : 'in_queue',
        _STATES.ARENA_WAITING  : 'arena_waiting',
        _STATES.ARENA_PREBATTLE: 'arena_prebattle',
        _STATES.ARENA_BATTLE   : 'arena_battle',
    }


    def __init__(self):
        import xfw_loader.python as loader
        xfwnative = loader.get_mod_module('com.modxvm.xfw.native')
        print(xfwnative.unpack_native('arukuka.discord_rich_presence'))
        self.__native = xfwnative.load_native('arukuka.discord_rich_presence', 'engine.pyd', 'engine')
        self.__native.init_engine()

        self.__settings = load_settings()

        self.__cache = {
            'vehicleDesc': None,
            'launched_time': int(time.time()),
            'timestamps': self.__native.ActivityTimestamps(),
            'state': self._STATES.UNKNOWN,
        }


    def __update_timestamps(self, state, next_timestamps):
        if self.__cache['state'] == state:
            return self.__cache['timestamps']
        else:
            self.__cache['timestamps'] = next_timestamps
            return next_timestamps


    def __generate_activity(self, state, info=dict()):
        timestamps = self.__native.ActivityTimestamps()

        if state in [self._STATES.IN_LOBBY, self._STATES.IN_QUEUE, self._STATES.ARENA_WAITING]:
            timestamps.start = int(time.time())
        elif state in [self._STATES.ARENA_PREBATTLE]:
            remain = BigWorld.player().arena.periodEndTime - BigWorld.serverTime()
            timestamps.end = int(time.time() + remain)
        elif state in [self._STATES.ARENA_BATTLE]:
            remain = BigWorld.player().arena.periodEndTime - BigWorld.serverTime()
            elapsed = BigWorld.player().arena.periodLength - remain
            timestamps.start = int(time.time() - elapsed)

        enabled = state != self._STATES.UNKNOWN and self.__settings[self._STATES_TO_JSON_KEY[state]]['enabled']
        if not enabled:
            timestamps.start = self.__cache['launched_time']

        timestamps = self.__update_timestamps(state, timestamps)

        activity = self.__native.Activity()
        activity.timestamps.start = timestamps.start
        activity.timestamps.end = timestamps.end

        if enabled:
            activity.state   = self.__settings[self._STATES_TO_JSON_KEY[state]]['state'  ].format(**info)
            activity.details = self.__settings[self._STATES_TO_JSON_KEY[state]]['details'].format(**info)

        activity.get_ref_activity_assets().large_image = 'icon'

        return activity


    def __get_vehicle_desc(self):
        vehicleDesc = None

        if hasattr(BigWorld.player(), 'vehicleTypeDescriptor'):
            vehicleDesc = BigWorld.player().vehicleTypeDescriptor

        if vehicleDesc is None and g_currentVehicle.item is not None:
            vehicleDesc = g_currentVehicle.item.descriptor

        if vehicleDesc is None:
            vehicleDesc = self.__cache['vehicleDesc']

        self.__cache['vehicleDesc'] = vehicleDesc

        return vehicleDesc


    def __get_vehicle_info(self):
        vehicleDesc = self.__get_vehicle_desc()

        vehicleName      = vehicleDesc.type.userString      if vehicleDesc is not None else ''
        vehicleShortName = vehicleDesc.type.shortUserString if vehicleDesc is not None else ''

        info = dict()
        info['#vehicleName']      = vehicleName
        info['#vehicleShortName'] = vehicleShortName

        return info


    def __common_process_arena(self):
        arenaType = BigWorld.player().arena.arenaType
        arenaGuiType = BigWorld.player().arenaGuiType
        arenaName = R.strings.arenas.num(arenaType.geometryName).dyn('name')()
        gameplayName = R.strings.arenas.type.dyn(arenaType.gameplayName).dyn('name')()

        arenaName = backport.text(arenaName)
        gameplayName = backport.text(gameplayName)
        from gui.battle_results.components.common import _ARENA_TYPE_EXT_FORMAT
        arenaGuiName = i18n.makeString(_ARENA_TYPE_EXT_FORMAT.format(arenaGuiType))

        info = dict()
        info['#arenaName']        = arenaName
        info['#gameplayName']     = gameplayName
        info['#arenaGuiName']     = arenaGuiName

        vehicle_info = self.__get_vehicle_info()
        info.update(vehicle_info)

        return info


    def __enter_lobby(self, *_):
        print('__enter_lobby')
        info = self.__get_vehicle_info()
        activity = self.__generate_activity(self._STATES.IN_LOBBY, info)
        self.__native.update_activity(activity)

        self.__cache['state'] = self._STATES.IN_LOBBY

    def __onArenaPeriodChange(self, period, *_):
        print('__onArenaPeriodChange', period, _)
        if self.__native is None:
            return

        from constants import ARENA_PERIOD
        if period not in (ARENA_PERIOD.WAITING, ARENA_PERIOD.PREBATTLE, ARENA_PERIOD.BATTLE):
            return

        info = self.__common_process_arena()

        if period == ARENA_PERIOD.WAITING:
            info["#waiting_message"] = backport.text(R.strings.ingame_gui.timer.waiting())

        PERIOD_TO_STATE = {
            ARENA_PERIOD.WAITING:   self._STATES.ARENA_WAITING,
            ARENA_PERIOD.PREBATTLE: self._STATES.ARENA_PREBATTLE,
            ARENA_PERIOD.BATTLE:    self._STATES.ARENA_BATTLE
        }
        activity = self.__generate_activity(PERIOD_TO_STATE[period], info)

        self.__native.update_activity(activity)

        self.__cache['state'] = PERIOD_TO_STATE[period]


    def __onEnqueued(self, spaceID):
        print('__onEnqueued')
        info = self.__get_vehicle_info()
        activity = self.__generate_activity(self._STATES.IN_QUEUE, info)
        self.__native.update_activity(activity)

        self.__cache['state'] = self._STATES.IN_QUEUE


    def __onGUISpaceEntered(self, spaceID):
        print('__onGUISpaceEntered')
        if spaceID == GuiGlobalSpaceID.LOBBY:
            # Is onChanged Event going to be cleared after battle...?
            # re-register because of that
            g_currentVehicle.onChanged -= self.__onCurrentVehicleChanged
            g_currentVehicle.onChanged += self.__onCurrentVehicleChanged

            self.__enter_lobby()


    def __onCurrentVehicleChanged(self):
        print('__onCurrentVehicleChanged')
        state = self.__cache['state']

        if state in [self._STATES.IN_LOBBY]:
            self.__enter_lobby()


    def run_callbacks(self):
        if self.__native is not None:
            self.__native.run_callbacks()


    def register_events(self):
        # Main Play Event
        from PlayerEvents import g_playerEvents
        g_playerEvents.onArenaPeriodChange += self.__onArenaPeriodChange

        # In Lobby
        g_playerEvents.onDequeued        += self.__enter_lobby
        g_playerEvents.onEnqueueFailure  += self.__enter_lobby
        g_playerEvents.onKickedFromQueue += self.__enter_lobby
        appLoader = dependency.instance(IAppLoader)
        appLoader.onGUISpaceEntered += self.__onGUISpaceEntered

        # In Queue
        g_playerEvents.onEnqueued += self.__onEnqueued


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

