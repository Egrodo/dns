#!/bin/bash

start=$(date +%s.%N)

main(){
    url="${1-google.com}"   # Establishing the argument as a variable
    cleanurl                # snipping off what is not a domain, if there is any.

    # Take advantage of processes captured in filedescriptors and call whois.
    exec {fdwhois}< <(whois "$domain")  # get whois data (in background).
    #echo "started whois $($date)"

    # Initiate the call to `host -t any`.
    # May get all domain records in one call ("if supported by the site").
    exec {fdrr}< <(host -t "any" "$domain")
    #echo "started any $($date)"


    ${fdrr+false} || {  rr=$(cat <&${fdrr}); exec {fdrr}<&- ; }
    if [[ $rr =~ "Please stop asking for ANY" ]]; then
        # Call for ANY resource records failed,
        # we need to call each record manually.
        exec {fdns}< <(host -t "ns"    "$domain")
        exec  {fda}< <(host -t "a"     "$domain")
        exec {fdmx}< <(host -t "mx"    "$domain")
    else
        gethost        # get Resource Records for the domain (from any).
    fi
    # read output of get file descriptors into variables and close each fd.
        ${fdns+false} || { nameserver=$(cat <&${fdns}); exec {fdns}<&- ; }
         ${fda+false} || {    address=$(cat <&${fda} ); exec  {fda}<&- ; }
        ${fdmx+false} || {         mx=$(cat <&${fdmx}); exec {fdmx}<&- ; }
        ${fdwi+false} || {  whoisdata=$(cat <&${fdwi}); exec {fdwi}<&- ; }
    # echo "host variables read $($date)"
    # read output of whois file descriptor into variables and close the fd.
     ${fdwhois+false} || { whoisdata=$(cat <&${fdwhois}); exec {fdwhois}<&- ; }
    # echo "whois data read $($date)"

     printingresults    # Pretty print the results.
}

cleanurl(){ # Convert a possible url into a dns domain.
    ### Remove `http(s)://` and `www.` and anything after `/`.
    [[ $url =~ ^(http(s)?://)?(www.)?([^/]*) ]]
    domain="${BASH_REMATCH[4]}"
    [[ ! $domain ]] && { echo "Invalid domain supplied"; exit 1; }
}

selecttype(){ # select lines that match the type of record.
    printf '%s' "$rr"| awk -v type="$1" '($0~type){print}'
}

gethost(){ # get Resource Records for the domain (from any).
    # Select each type of "Resource Records":
    nameserver="$(selecttype "name server")"
    address="$(selecttype "address")"
    mx="$(selecttype "mail is handled by")"
    soa="$(selecttype "has SOA record")"
    txt="$(selecttype "descriptive text")"
}


printingresults(){ # Pretty print the results from the code.
    #Establishing color codes.
    cyan='\033[1;34m'
    white='\033[0;37m'
    purple='\033[38;5;129m'
    NC='\033[0m'
    BT=$(tput bold)
    NT=$(tput sgr0)

    # printing the variables to the terminal and plain text for readability.
    lines=("Simplified DNS Record Information for")
    lines+=("Below is my best attempt at finding the Registrar info")
    lines+=("Nameservers")
    lines+=("A Records")
    lines+=("MX Records")
    lines+=("SOA Records")
    lines+=("TXT Records")
    madeby="${purple}Made by Noah Yamamoto${NC}\n"
    end=$(date +%s.%N) 
    reg=$(whois "$domain" | grep -Ei '^[[:blank:]]+.*:[[:blank:]]' | sed -e 's/^[[:space:]]*//')
    reginfo=$(sed '/^Domain/d;/^Referral/d;/^Whois/d;/^Sponsoring/d' <<<"$reg")
    runtime=$(echo -e "$end - $start" | bc -l )
    howlong="${purple}Your search took: $runtime seconds.${NC}\n"
    printline="$(printf "${cyan}%s:\n${white}%%s\n\n" "${lines[@]}"; printf "${cyan}${NT}$howlong${purple}${BT}$madeby")"
    printf "$printline\n" "$domain" "$reginfo" "$nameserver" "$address" "$mx" "$soa" "$txt" 
}

main "$@"
