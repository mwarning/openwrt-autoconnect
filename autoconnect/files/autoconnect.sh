#!/bin/sh

# Set these variables
selected_cfg="radio0"
selected_dev="wlan0"

#######################################################

. /lib/functions.sh

scanned_ssid=""
scanned_channel=""

config_load 'wireless'

is_cfg_disabled() {
  local device="$1"
  local disabled=1
  uci_get disabled "$device" disabled
  [ $disabled -eq 0 ]
}

is_dev_present() {
  [ ! -f /sys/class/net/wlan0/operstate ]
}

if is_cfg_disabled "$selected_cfg"; then
  echo "WIFI configuration disabled: $selected_cfg"
  exit 1
fi

if is_dev_present "$selected_dev"; then
  echo "WIFI device does not exist: $selected_dev"
  exit 1
fi

#wifi_status="$(wifi status 2> /dev/null)"
iw_scan="$(iw dev ${selected_dev} scan 2> /dev/null)"
if [ $? -ne 0 ]; then
  echo "WIFI scan failed - try again"
  exit 1
fi

listed_ssid() {
  local search_ssid="$1"
  local found=0

  check() {
    local cfg="$1"
    local ssid mode

    config_get ssid $cfg ssid
    config_get mode $cfg mode

    if [ "$mode" = "sta" -a "$search_ssid" = "$ssid" ]; then
      found=1
      return 0
    else
      return 1
    fi
  }

  config_foreach check 'wifi-iface'
}

select_wifi() {
  local scanned_ssid="$1"
  local scanned_channel="$2"
  local changed=0

  apply() {
    local cfg="$1"
    local device ssid disabled channel

    config_get device $cfg device
    config_get ssid $cfg ssid
    config_get disabled $cfg disabled
    config_get channel $selected_cfg channel

    if [ "$device" = "$selected_cfg" ]; then
      if [ "$ssid" = "$scanned_ssid" ]; then
        if [ $disabled -ne 0 -o $channel -ne $scanned_channel ]; then
          uci set wireless.$cfg.disabled=0
          uci set wireless.$selected_cfg.channel=$scanned_channel
          changed=1
        fi
      else
        if [ $disabled -ne 1 ]; then
          uci set wireless.$cfg.disabled=1
          changed=1
        fi
      fi
    fi
  }

  config_foreach apply 'wifi-iface'

  echo "SSID: '$scanned_ssid', channel: $scanned_channel"
  if [ $changed -eq 1 ]; then
    echo "Configuration changed - reload"
    wifi
  else
    echo "Configuration unchanged"
  fi
}

parse_scan() {
  local iw_scan="$1"
  local ssid=""
  local channel=""

  echo "$iw_scan" | while read line
  do
    case "$line" in
      "BSS"*)
        ssid=""
        channel=""
        ;;
      "SSID: "*)
        ssid="${line:6}"
        ;;
      "* primary channel: "*)
        channel="${line:19}"
        ;;
    esac

    if [ -n "$channel" -a -n "$ssid" ]; then
      if listed_ssid "$ssid"; then
        select_wifi "$ssid" "$channel"
        return
      fi

      ssid=""
      channel=""
    fi
  done
}

parse_scan "$iw_scan"

scan() {
  ifconfig wlan0 down
  iw phy phy0 interface add scan0 type station
  ifconfig scan0 up
  iwlist scan0 scan
  iw dev scan0 del
  ifconfig wlan0 up
  killall -HUP hostapd
}

