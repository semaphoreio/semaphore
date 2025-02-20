#!/bin/bash
USAGE=$(git --no-pager grep -r "TODO" ':(exclude)*todos_count.sh' | wc -l)
USAGE_LIMIT=20

echo "TODO word is used in $USAGE places (limit $USAGE_LIMIT)."

if [ $USAGE -gt $USAGE_LIMIT ]; then
  OVER_LIMIT=`printf %4d $(($USAGE-$USAGE_LIMIT))`
  echo "Files: "
  echo -e "$(git --no-pager grep -r "TODO" ':(exclude)*todos_count.sh')"

  echo
  echo "======================= WARNING ========================"
  echo "= Please resolve at least $OVER_LIMIT TODOs before continuing ="
  echo "========================================================"
  echo

  exit 1
fi
