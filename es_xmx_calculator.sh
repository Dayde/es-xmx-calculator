#/bin/sh

MAXIMUM_MEMORY_MB=$(free -m | grep Mem | awk '{print $2}')

echo "Maximum memory is ${MAXIMUM_MEMORY_MB}m."

echo "Is ElasticSearch the only memory consuming process on this server?"
select yn in "Yes" "No"; do
  case $yn in
    Yes ) MEMORY_ALREADY_ALLOCATED=0; break;;
    No ) echo "How much memory in MB is allocated for them ?"; read MEMORY_ALREADY_ALLOCATED; break;;
  esac
done

ES_MEMORY=$((${MAXIMUM_MEMORY_MB}-${MEMORY_ALREADY_ALLOCATED}))

echo "Assuming ${ES_MEMORY}MB of memory is available for ElasticSearch..."

HALF_MEMORY=$((${ES_MEMORY}/2))

HALF=$(java -Xmx${HALF_MEMORY}m -XX:+PrintFlagsFinal 2> /dev/null | grep UseCompressedOops | grep -c true)
if [ ${HALF} -eq 1 ]
then
  echo "Half of the memory should be allocated to ElasticSearch (-Xmx${HALF_MEMORY}m)."
else
  # ElasticSearch documentation says it is safe to assume compressed OOPs is enabled at 31GB of memory
  LOW=31000
  HIGH=${HALF_MEMORY}
  while [ $((${HIGH}-${LOW})) -gt 1 ]
  do
    MIDDLE=$((${LOW}+(${HIGH}-${LOW})/2))
    COMPRESSED_OOPS_ENABLED=$(java -Xmx${MIDDLE}m -XX:+PrintFlagsFinal 2> /dev/null | grep UseCompressedOops | grep -c true)
    if [ ${COMPRESSED_OOPS_ENABLED} -eq 1 ]
    then
      LOW=${MIDDLE}
    else
      HIGH=${MIDDLE}
    fi
  done
  echo "The server has too much memory to stay efficient with half the memory allocated to ElasticSearch."
  echo "Only ${LOW}MB should be allocated (-Xmx${LOW}m)."
fi
