#!/bin/bash -eu

IFACE_ETH0="eth0"
IFACE_LO="lo"
PREFIX_LEN="128"

# get Droplet metadata
md=$(curl -s 169.254.169.254/metadata/v1.json)

# get reserved IPv6 info from metadata
md_rip6_json=$(echo "${md}" | jq -r '.reserved_ip.ipv6')

case "$(echo "${md_rip6_json}" | jq -r '.active')" in
    "true")
        # if active, set up interface and routes
        rip6=$(echo "${md_rip6_json}" | jq -r '.ip_address')
        ip -6 addr replace "${rip6}/${PREFIX_LEN}" dev ${IFACE_LO} scope global
        echo "Assigned ${rip6}/${PREFIX_LEN} to ${IFACE_LO}"
        ip -6 route replace default dev ${IFACE_ETH0}
        echo "Created default IPv6 route via ${IFACE_ETH0}"
        ;;

    "false")
        # if inactive, clean up interface and routes
        ip -6 addr flush dev ${IFACE_LO} scope global
        echo "Removed all Reserved IPv6 addresses from ${IFACE_LO}"
        # technically, the route can remain even beyond removal,
        # but to keep consistency with existing behavior without
        # a reserved IPv6, we'll clean it up
        if [[ "$(ip -6 route show default dev ${IFACE_ETH0})" != "" && "$(ip -6 addr show dev ${IFACE_ETH0} scope global)" == "" ]]; then
            ip -6 route delete default dev ${IFACE_ETH0}
            echo "Deleted default IPv6 route via ${IFACE_ETH0}"
        fi
        ;;
esac
