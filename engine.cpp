#include <csignal>
#include <thread>
#include <iostream>
#include <chrono>

#include <pybind11/pybind11.h>
#include <discord.h>

struct DiscordState {
    std::unique_ptr<discord::Core> core;
};

DiscordState state{};

void update_activity(const discord::Activity& activity)
{
    state.core->ActivityManager().UpdateActivity(activity, [](discord::Result result) {
        std::cout << ((result == discord::Result::Ok) ? "Succeeded" : "Failed")
                  << " updating activity!\n";
    });
}

bool init_engine()
{
    discord::Core* core{};
    auto result = discord::Core::Create(855727174850183188, DiscordCreateFlags_Default, &core);
    state.core.reset(core);
    discord::Activity activity{};
    activity.GetAssets().SetLargeImage("icon");
    activity.GetTimestamps().SetStart(
        std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::system_clock::now().time_since_epoch()
        ).count()
    );
    activity.SetType(discord::ActivityType::Playing);
    state.core->ActivityManager().UpdateActivity(activity, [](discord::Result result) {
        std::cout << ((result == discord::Result::Ok) ? "Succeeded" : "Failed")
                  << " updating activity!\n";
    });
    return result == discord::Result::Ok;
}

void run_callbacks()
{
    state.core->RunCallbacks();
}

PYBIND11_MODULE(engine, m)
{
    m.doc() = "wotmods";
    m.def("init_engine", &init_engine, "");
    m.def("run_callbacks", &run_callbacks, "");
    m.def("update_activity", &update_activity, "");

    pybind11::enum_<discord::ActivityType>(m, "ActivityType")
        .value("Playing",   discord::ActivityType::Playing)
        .value("Streaming", discord::ActivityType::Streaming)
        .value("Listening", discord::ActivityType::Listening)
        .value("Watching",  discord::ActivityType::Watching)
        ;

    pybind11::class_<discord::ActivityTimestamps>(m, "ActivityTimestamps")
        .def(pybind11::init<>())
        .def_property("start",
                      &discord::ActivityTimestamps::GetStart,
                      &discord::ActivityTimestamps::SetStart)
        .def_property("end",
                      &discord::ActivityTimestamps::GetEnd,
                      &discord::ActivityTimestamps::SetEnd)
        ;

    pybind11::class_<discord::ActivityAssets>(m, "ActivityAssets")
        .def(pybind11::init<>())
        .def_property("large_image",
                      &discord::ActivityAssets::GetLargeImage,
                      &discord::ActivityAssets::SetLargeImage)
        .def_property("large_text",
                      &discord::ActivityAssets::GetLargeText,
                      &discord::ActivityAssets::SetLargeText)
        .def_property("small_image",
                      &discord::ActivityAssets::GetSmallImage,
                      &discord::ActivityAssets::SetSmallImage)
        .def_property("small_text",
                      &discord::ActivityAssets::GetSmallText,
                      &discord::ActivityAssets::SetSmallText)
        ;

    pybind11::class_<discord::PartySize>(m, "PartySize")
        .def(pybind11::init<>())
        .def_property("current_size",
                      &discord::PartySize::GetCurrentSize,
                      &discord::PartySize::SetCurrentSize)
        .def_property("max_size",
                      &discord::PartySize::GetMaxSize,
                      &discord::PartySize::SetMaxSize)
        ;

    pybind11::class_<discord::ActivityParty>(m, "ActivityParty")
        .def(pybind11::init<>())
        .def_property("id",
                      &discord::ActivityParty::GetId,
                      &discord::ActivityParty::SetId)
        .def("get_ref_size",
             pybind11::overload_cast<>(&discord::ActivityParty::GetSize),
             pybind11::return_value_policy::reference)
        ;

    pybind11::class_<discord::ActivitySecrets>(m, "ActivitySecrets")
        .def(pybind11::init<>())
        .def_property("match",
                      &discord::ActivitySecrets::GetMatch,
                      &discord::ActivitySecrets::SetMatch)
        .def_property("join",
                      &discord::ActivitySecrets::GetJoin,
                      &discord::ActivitySecrets::SetJoin)
        .def_property("spectate",
                      &discord::ActivitySecrets::GetSpectate,
                      &discord::ActivitySecrets::SetSpectate)
        ;

    pybind11::class_<discord::Activity>(m, "Activity")
        .def(pybind11::init<>())
        .def_property("details",
                      &discord::Activity::GetDetails,
                      &discord::Activity::SetDetails)
        .def_property("type",
                      &discord::Activity::GetType,
                      &discord::Activity::SetType)
        .def_property("application_id",
                      &discord::Activity::GetApplicationId,
                      &discord::Activity::SetApplicationId)
        .def_property("name",
                      &discord::Activity::GetName,
                      &discord::Activity::SetName)
        .def_property("state",
                      &discord::Activity::GetState,
                      &discord::Activity::SetState)
        // .def("get_ref_timestamps",
        //      pybind11::overload_cast<>(&discord::Activity::GetTimestamps),
        //      pybind11::return_value_policy::reference)
        .def_property("timestamps",
                      pybind11::cpp_function(pybind11::overload_cast<>(&discord::Activity::GetTimestamps), pybind11::return_value_policy::reference),
                      nullptr)
        .def("get_ref_activity_assets",
             pybind11::overload_cast<>(&discord::Activity::GetAssets),
             pybind11::return_value_policy::reference)
        .def("get_ref_party",
             pybind11::overload_cast<>(&discord::Activity::GetParty),
             pybind11::return_value_policy::reference)
        .def("get_ref_secrets",
             pybind11::overload_cast<>(&discord::Activity::GetSecrets),
             pybind11::return_value_policy::reference)
        .def_property("instance",
                      &discord::Activity::GetInstance,
                      &discord::Activity::SetInstance)
        ;
}
