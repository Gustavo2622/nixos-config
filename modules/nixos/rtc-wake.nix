# RTC wake: schedule the desktop to power on daily at 09:00 local time.
# Sets the RTC alarm via a systemd service that runs before sleep and on a daily timer.
{pkgs, ...}: let
  rtcWakeScript = pkgs.writeShellScript "rtc-wake-set" ''
    now=$(date +%s)
    today_nine=$(date -d "today 09:00" +%s)
    tomorrow_nine=$(date -d "tomorrow 09:00" +%s)
    if [ "$now" -lt "$today_nine" ]; then
      target=$today_nine
    else
      target=$tomorrow_nine
    fi
    echo "Setting RTC wake for $(date -d @"$target")"
    ${pkgs.util-linux}/bin/rtcwake -m no -t "$target"
  '';
in {
  systemd.services.rtc-wake-set = {
    description = "Set RTC wake alarm for next 09:00";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = rtcWakeScript;
    };
    # Run before suspend and before shutdown
    wantedBy = ["sleep.target" "shutdown.target"];
    before = ["sleep.target" "shutdown.target"];
  };

  # Daily timer to keep the alarm fresh (in case the machine stays on past 09:00)
  systemd.timers.rtc-wake-set = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
