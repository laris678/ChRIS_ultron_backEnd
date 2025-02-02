#!/usr/bin/env bash
#
# NAME
#
#   plugin_add.sh
#
# SYNPOSIS
#
#   plugin_add.sh [-t dev|deploy]                                       \
#                 [-s <step>] [-j]                                      \
#                 <commaSeparatedListOfPluginSpecsToAdd>
#
# DESC
#
#   'plugin_add.sh' adds new plugins to an existing and instantiated
#   CUBE.
#
# Notes on pluginList
#
# The plugin list is a comma separated list, each element conforming to a
# cparse specification, e.g.:
#
#           fnndsc/pl-pfdicom_tagextract^moc
#
# templatized as:
#
#       [<repo>/]<container>[^<env>]
#
##
# ARGS
#
#   [-t dev|deploy]
#
#       Choose either 'dev' or 'deploy' targets. This affects the choice of
#       underlying docker-compose yaml to process as well as the name of the
#       chris service.
#
#       Default is 'dev'.
#
#   [-s <step>]
#
#       Start STEP counter at <step>. This is useful for cases when
#       this script is called from another staged script and contintuity
#       requires a <step> offset.
#
#   [-j]
#
#       Show JSON representation. If specified, also "print" a given plugin
#       JSON representation during the store registration phase.
#

source ./decorate.sh
source ./cparse.sh

DOCKER_COMPOSE_FILE=docker-compose_dev.yml
CHRIS=chris_dev
TARGET=dev
declare -i STEP=0
declare -i b_json=0
declare -i thisStatusCheckOK=0
HERE=$(pwd)
LINE="------------------------------------------------"

if [[ -f .env ]] ; then
    source .env
fi

status_check () {
    STATUS=$1
    RIGHT2=$2
    thisStatusCheckOK=0
    if [[ $STATUS == "0" ]] ; then
        thisStatusCheckOK=1
        b_statusSuccess=$(( b_statusSuccess+=1 ))
        echo -en "\033[3A\033[2K"
        if (( ! ${#RIGHT2} ))  ; then
            RIGHT2="success"
        fi
        opSolid_feedback "$LEFT1" "$LEFT2"  "$RIGHT1" "$RIGHT2"
    else
        b_statusFail=$(( b_statusFail+=1 ))
        echo -en "\033[3A\033[2K"
        if (( ! ${#RIGHT2} ))  ; then
            RIGHT2="fail"
        fi
        opFail_feedback "$LEFT1" "$LEFT2"  "$RIGHT1" "$RIGHT2"
        if [[ -f dc.out ]] ; then
            cat dc.out                                                      |\
            sed 's/[[:alnum:]]+:/\n&/g'                                     |\
            sed -E 's/(.{80})/\1\n/g'                                       | ./boxes.sh LightRed
        fi
    fi
}

catw() {
    FILE=$1
    COLOR=$2
    if (( !${#COLOR} )) ; then
        COLOR=White
    fi
    if [[ -f $FILE ]] ; then
        cat dc.out                                                      |\
        sed 's/[[:alnum:]]+:/\n&/g'                                     |\
        sed -E 's/(.{80})/\1\n/g'                                       | ./boxes.sh $COLOR
    fi
}

dc_check () {
    STATUS=$1
    DCECHO=$2
    thisStatusCheckOK=0
    if [[ $STATUS != "0" ]] ; then
        if (( ${#DCECHO} )) ; then
            echo -en "\033[2A\033[2K"
            catw dc.out LightRed
        else
            echo -en "\033[3A\033[2K"
        fi
    else
        thisStatusCheckOK=1
        if (( ${#DCECHO} )) ; then
            echo -en "\033[2A\033[2K"
            catw dc.out White
        else
            echo -en "\033[3A\033[2K"
        fi
    fi
}

dc_check_code () {
    STATUS=$1
    CODE=$2
    DCECHO=$3
    if (( $CODE > 1 )) ; then
        if [[ ${#DCECHO} ]] ; then
            echo -en "\033[2A\033[2K"
            catw dc.out LightRed
        else
            echo -en "\033[3A\033[2K"
        fi
    else
        if [[ ${#DCECHO} ]] ; then
            echo -en "\033[2A\033[2K"
            catw dc.out White
        else
            echo -en "\033[3A\033[2K"
        fi
    fi
}

function opBlink_feedback {
    #
    # ARGS
    #       $1          left string to print
    #       $2          some description of op
    #       $3          current action
    #       $4          current action state
    #
    # Pretty print some operation in a blink state
    #
    leftID=$(center "${1:0:18}" 18)
    op=$2
    action=$3
    result=$(center "${4:0:12}" 12)

    # echo -e ''$_{1..8}'\b0123456789'
    # echo " --> $leftID <---"
    printf "\
${LightBlueBG}${White}[%*s]${NC}\
${LightCyan}%-*s\
${Yellow}%*s\
${blink}${LightGreen}[%-*s]\
${NC}\n" \
        "18" "${leftID:0:18}"       \
        "32" "${op:0:32}"           \
        "14" "${action:0:14}"       \
        "12" "${result:0:12}"       | ./boxes.sh
}

function opSolid_feedback {
    #
    # ARGS
    #       $1          left string to print
    #       $2          some description of op
    #       $3          current action
    #       $4          current action state
    #
    # Pretty print some operation in a solid state
    #
    leftID=$(center "${1:0:18}" 18)
    op=$2
    action=$3
    result=$(center "${4:0:12}" 12)

    # echo -e ''$_{1..8}'\b0123456789'
    printf "\
${LightBlueBG}${White}[%*s]${NC}\
${LightCyan}%-*s\
${Yellow}%*s\
${LightGreenBG}${White}[%-*s]\
${NC}\n" \
        "18" "${leftID:0:18}"       \
        "32" "${op:0:32}"           \
        "14" "${action:0:14}"       \
        "12" "${result:0:12}"       | ./boxes.sh
}

function opFail_feedback {
    #
    # ARGS
    #       $1          left string to print
    #       $2          some description of op
    #       $3          current action
    #       $4          current action state
    #
    # Pretty print some operation in a failed state
    #
    leftID=$(center "${1:0:18}" 18)
    op=$2
    action=$3
    result=$(center "${4:0:12}" 12)

    # echo -e ''$_{1..8}'\b0123456789'
    printf "\
${LightBlueBG}${White}[%*s]${NC}\
${LightCyan}%-*s\
${Yellow}%*s\
${LightRedBG}${White}[%-*s]\
${NC}\n" \
        "18" "${leftID:0:18}"       \
        "32" "${op:0:32}"           \
        "14" "${action:0:14}"       \
        "12" "${result:0:12}"       | ./boxes.sh
}

while getopts "t:s:j" opt; do
    case $opt in
        s)  STEP=$OPTARG
            STEP=$(( STEP -1 ))                 ;;
        t)  TARGET=$OPTARG                      ;;
        j)  b_json=1                            ;;
    esac
done

case $TARGET in
    dev)    DOCKER_COMPOSE_FILE=docker-compose_dev.yml
            CHRIS=chris_dev
            ;;
    deploy) DOCKER_COMPOSE_FILE=docker-compose.yml
            CHRIS=chris
            ;;
    *)      DOCKER_COMPOSE_FILE=docker-compose_dev.yml
            CHRIS=chris_dev
            ;;
esac

declare -a a_PLUGINRepoEnv=()
declare -a a_storePluginUser=()
declare -a a_storePluginOK=()

shift $(($OPTIND - 1))
L_PLUGINS=$*
IFS=',' read -ra a_PLUGINRepoEnv <<< "$L_PLUGINS"

title -d 1 "Creating array of <REPO>/<CONTAINER> from plugin list..."
    for plugin in "${a_PLUGINRepoEnv[@]}" ; do
        cparse $plugin "REPO" "CONTAINER" "MMN" "ENV"
        tcprint Yellow "Processing env [$ENV] for " LightCyan "$REPO/$CONTAINER" "40" "-40"
        a_storePluginUser+=("$REPO/$CONTAINER")
    done
    a_storePluginUser=($(printf "%s\n" "${a_storePluginUser[@]}" | sort -u | tr '\n' ' '))
windowBottom

title -d 1 "Removing any duplicate <REPO>/<CONTAINER> from plugin list..."
    a_storePluginUser=($(printf "%s\n" "${a_storePluginUser[@]}" | sort -u | tr '\n' ' '))
    numElements=${#a_storePluginUser[@]}
    tcprint "Yellow" "Unique hits " LightCyan "$numElements" "40" "-40"
    for plugin in "${a_storePluginUser[@]}" ; do
        tcprint Yellow "Image " LightCyan $plugin "40" "-40"
    done
windowBottom

title -d 1  "Checking on container plugins " \
            "and pulling latest versions where needed..."
    let b_statusSuccess=0
    let b_statusFail=0
    for plugin in "${a_storePluginUser[@]}" ; do
        cparse $plugin "REPO" "CONTAINER" "MMN" "ENV"
        LEFT1=$CONTAINER;       LEFT2="::$REPO (pulling)"
        RIGHT1="latest<--";     RIGHT2="pulling"
        if [[ $REPO != "local" ]] ; then
            opBlink_feedback "$LEFT1" "$LEFT2" "$RIGHT1" "pulling"
            windowBottom
            CMD="docker pull $REPO/$CONTAINER"
            RIGHT1="latest-->"; LEFT2="::$REPO (pulled)"
            echo $CMD | sh >& dc.out >/dev/null
            status=$?
            status_check $status
            if (( status == 0 )) ; then
                a_storePluginOK+=("$plugin")
            fi
        else
            a_storePluginOK+=("$plugin")
        fi
    done
    if (( b_statusSuccess > 0 )) ; then
        echo ""                                                         | ./boxes.sh
        printf "${LightCyan}%27s${LightGreen}%-53s${NC}\n"              \
            "$b_statusSuccess"                                          \
            " images successfully pulled"                               | ./boxes.sh
        echo ""                                                         | ./boxes.sh
    fi
    if (( b_statusFail > 0 )) ; then
        echo ""                                                         | ./boxes.sh
        printf "${LightRed}%27s${Brown}%-53s${NC}\n"                    \
            "$b_statusFail"                                             \
        " images were not successfully pulled."                         | ./boxes.sh
        boxcenter " "
        boxcenter "The attempt to pull some containers resulted in a "  ${LightRed}
        boxcenter "failure. There are many possible reasons for this "  ${LightRed}
        boxcenter "but the first thing to verify  is that  the image "  ${LightRed}
        boxcenter "names passed are correct. You  can  also directly "  ${LightRed}
        boxcenter "try and pull the failed images with               "  ${LightRed}
        boxcenter " "
        boxcenter "docker pull <imageName> "                            ${White}
        boxcenter " "
        boxcenter "Note that  if  you do  NOT  have sudoless docker "   ${Yellow}
        boxcenter "configured, you  should run  this  script using  "   ${Yellow}
        boxcenter " "
        boxcenter "sudo ./plugin_add.sh ..."                            ${White}
        boxcenter " "
    fi
windowBottom

title -d 1 "Uploading plugin representations to the ChRIS store..."
    declare -i i=1
    declare -i b_already=0
    let b_statusSuccess=0
    let b_statusFail=0
    declare -i b_uploadSuccess=0
    declare -i b_uploadFail=0
    declare -i b_noStore=0
    echo ""                                                                         | ./boxes.sh
    echo ""                                                                         | ./boxes.sh
    for plugin in "${a_storePluginOK[@]}"; do
        echo -en "\033[2A\033[2K"
        cparse $plugin "REPO" "CONTAINER" "MMN" "ENV"
        CMD="docker run --rm $REPO/$CONTAINER ${MMN} --json 2>/dev/null > rep.json"
        CMD2="docker run --rm $REPO/$CONTAINER chris_plugin_info > rep.json"

        str_count=$(printf "%2s" "$i")
        LEFT1=$CONTAINER;                   LEFT2="${str_count}::JSON<--parse"
        RIGHT1="<-- <-- <-- <-"             RIGHT2="in progress"
        opBlink_feedback "$LEFT1" "$LEFT2" "$RIGHT1" "$RIGHT2"
        windowBottom

        eval $CMD
        status=$?
        if (( $status )) ; then
            eval $CMD2
        fi
        PLUGIN_REP=$(cat rep.json)
        strPLUGIN_REP=$(cat rep.json | jq tostring)
        status=$?
        # rm rep.json
        status_check $status
        if (( !thisStatusCheckOK )) ; then
            windowBottom
            continue
        fi
        ((b_statusSuccess--))
        if (( b_json )) ; then
            echo "$PLUGIN_REP" | python -m json.tool                                |\
                sed 's/[[:alnum:]]+:/\n&/g' | sed -E 's/(.{80})/\1\n/g'             | ./boxes.sh ${LightGreen}
        fi

        LEFT2="${str_count}::JSON-->Store" ; RIGHT2="in progress"
        echo -en "\033[1A\033[2K"
        opBlink_feedback "$LEFT1" "$LEFT2" "$RIGHT1" "$RIGHT2"
        windowBottom
        ## HORRID HACK ALERT (Jan 2022)
        ## There seems no way to capture cleanly the std[out/err] from the
        ## python call within the "docker-compose exec chris_store"
        ## One hacky solution is to execute the python manager.py as a
        ## sh -c within the container and capture str[out/err] *within*
        ## the container FS. This means that the generated dc.out needs to
        ## be copied from the chris_store FS which is just many levels of
        ## horribleness. Maybe a better solution can be found?
        docker-compose -f $DOCKER_COMPOSE_FILE                                \
            exec chris_store sh -c                                            \
            "python plugins/services/manager.py add $CONTAINER                \
            cubeadmin https://github.com/FNNDSC $REPO/$CONTAINER              \
            --descriptorstring $strPLUGIN_REP >dc.out 2>&1"
        status=$?
        # Copy dc.out from the chris_store container to local FS
        docker cp $(docker ps | grep chris_store | head -n 1                 |\
                    awk '{print $1}'):/home/localuser/store_backend/dc.out ./
        RIGHT1="--> --> --> ->"
        RIGHT2=""
        b_NR=$(cat dc.out | grep -c "not running")
        b_exist=$(cat dc.out | grep -c "already exists")
        b_previous=$(cat dc.out | grep -c "already used")
        if ((  b_exist || b_previous)) ; then
            cat dc.out                              |\
                grep 'already'                      |\
                awk -F "string="  '{print $2}'      |\
                awk -F ', code' '{print $1}'    > dc.out
            VER=$(cat dc.out                        |\
                    awk -F "version" '{print $2}'   |\
                    awk -F "already" '{print $1}')
            rm dc.out 
            RIGHT2="$VER"
            if (( !${#VER} )) ; then
                RIGHT2="already"
            fi
            ((b_already++))
        fi
        status_check $status "$RIGHT2"
        if (( b_NR )) ; then
            ((b_statusSuccess--))
            echo -en "\033[1A\033[2K"
            opFail_feedback "$LEFT1" "$LEFT2" "$RIGHT1" "no store"
            boxcenter "$(cat dc.out)" LightRed
            b_uploadFail=1
            b_noStore=1
            windowBottom
            break
        fi
        ((i++))
        windowBottom
    done
    echo -en "\033[2A\033[2K"
    echo ""                                                             | ./boxes.sh
    if (( b_statusSuccess > 0 )) ; then
        printf "${LightCyan}%16s${LightGreen}%-64s${NC}\n"              \
            "$b_statusSuccess"                                          \
            " representation(s) successfully uploaded to ChRIS Store"   | ./boxes.sh
        echo ""                                                         | ./boxes.sh
    fi
    if (( b_already > 0 )) ; then
        printf "${LightCyan}%16s${Yellow}%-64s${NC}\n"                  \
            "$b_already"                                                \
            " representation(s) were already in the ChRIS Store"        | ./boxes.sh
        boxcenter "An 'already' state simply means the representation"  ${LightPurple}
        boxcenter "is already in the ChRIS Store --  most  likely due"  ${LightPurple}
        boxcenter "a prior attempt at registration.  Also, note  that"  ${LightPurple}
        boxcenter "if the same plugin is processed ultimately to many"  ${LightPurple}
        boxcenter "compute  environments,  an 'already' state will be"  ${LightPurple}
        boxcenter "triggered. This state is harmless and merely is  a"  ${LightPurple}
        boxcenter "warning.                                          "  ${LightPurple}
        echo ""                                                         | ./boxes.sh
    fi
    if (( b_uploadFail > 0 )) ; then
        printf "${LightRed}%16s${Brown}%-64s${NC}\n"                    \
            "$b_uploadFail"                                             \
        " representation(s) did not upload to ChRIS Store."             | ./boxes.sh
        boxcenter "The attempt to upload some plugin representations "  ${LightRed}
        boxcenter "had a complete failure. This could mean that the  "  ${LightRed}
        boxcenter "plugin itself did not exist or download, or if it "  ${LightRed}
        boxcenter "did, the plugin might not correctly service the   "  ${LightRed}
        boxcenter "'--json' flag to create a representation.         "  ${LightRed}
        echo ""                                                         | ./boxes.sh
        boxcenter "Also, check that the ChRIS store is running!      "  ${LightRed}
        echo ""                                                         | ./boxes.sh
        boxcenter "This is a critical/unrecoverable failure.         "  ${LightRed}
        echo ""                                                         | ./boxes.sh
    fi
windowBottom
if (( b_noStore )) ; then exit 1 ; fi

title -d 1 "Automatically registering some plugins from the ChRIS store" \
           "with associated compute environment in ChRIS..."
    declare -i i=1
    declare -i b_statusSuccess=0
    declare -i b_statusFail=0
    echo ""                                                             | ./boxes.sh
    echo ""                                                             | ./boxes.sh
    for plugin in "${a_storePluginOK[@]}"; do
        echo -en "\033[2A\033[2K"
        cparse $plugin "REPO" "CONTAINER" "MMN" "ENV"

        str_count=$(printf "%2s" "$i")
        LEFT1=$CONTAINER;                   LEFT2="${str_count}::Store-->ChRIS (add)"
        RIGHT1="<-- <-- <-- <-"             RIGHT2="in progress"
        opBlink_feedback "$LEFT1" "$LEFT2" "$RIGHT1" "$RIGHT2"
        windowBottom
        computeDescription="${ENV} description"
        docker-compose -f ${DOCKER_COMPOSE_FILE}                        \
            exec ${CHRIS} python plugins/services/manager.py            \
            add "$ENV" "http://pfcon.remote:30005/api/v1/"              \
            --description "$ENV Description" >& dc.out
        status=$?
        status_check $status
        echo -en "\033[1A\033[2K"
        LEFT2="${str_count}::Store-->ChRIS (register)" ; RIGHT2="in progress"
        opBlink_feedback "$LEFT1" "$LEFT2" "$RIGHT1" "$RIGHT2"
        windowBottom
        docker-compose -f ${DOCKER_COMPOSE_FILE}                              \
            exec ${CHRIS} sh -c                                               \
            "python plugins/services/manager.py                               \
             register $ENV --pluginname $CONTAINER  > /tmp/dc.out 2>&1"
        status=$?
        # Copy dc.out from the chris_store container to local FS
        docker cp $(docker ps | grep $CHRIS | head -n 1                       |\
                    awk '{print $1}'):/tmp/dc.out ./
        RIGHT1="--> --> --> ->"
        status_check $status $ENV
        windowBottom
        ((b_statusSuccess--))
        ((i++))
    done

    echo -en "\033[2A\033[2K"
    echo ""                                                             | ./boxes.sh
    if (( b_statusSuccess >= 0 )) ; then
        printf "${LightCyan}%18s${LightGreen}%-62s${NC}\n"              \
            "$b_statusSuccess"                                          \
            " plugin(s)+env(s) successfully registered to ChRIS"        | ./boxes.sh
        echo ""                                                         | ./boxes.sh
    fi
    if (( b_statusFail )) ; then
        printf "${Red}%18s${Brown}%-62s${NC}\n"                         \
            "$b_statusFail"                                             \
            " plugin(s)+env(s)  failed  to  register  to ChRIS."        | ./boxes.sh
        boxcenter "Plugins that failed to register to ChRIS will not"    ${LightRed}
        boxcenter "be available for use in the system.  Please check"    ${LightRed}
        boxcenter "the  plugin  download  and/or  store registration"    ${LightRed}
        boxcenter "steps for possible insights.                     "    ${LightRed}
        echo ""                                                         | ./boxes.sh
    fi
    echo ""                                                             | ./boxes.sh
    windowBottom

