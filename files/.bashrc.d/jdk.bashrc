#export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java::")
export JAVA_HOME=${JAVA_HOME:=$(find /usr/java/ -maxdepth 1 -name "jdk*")}
export JRE_HOME=${JRE_HOME:=$JAVA_HOME}
export JDK_HOME=${JDK_HOME:=$JAVA_HOME}
export PATH=$PATH:$JAVA_HOME/bin