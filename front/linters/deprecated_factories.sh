USAGE=$(grep -r "Support.Factories." test | wc -l)

USAGE_LIMIT=277

echo "Support.Factories is used in $USAGE places (limit $USAGE_LIMIT)"
echo ""


if [ $USAGE -gt $USAGE_LIMIT ]; then
  echo "Usage of Support.Factories is no longer considered a good practice in this repository"
  echo "The upper limit on the number of times that the old system can be used is $USAGE_LIMIT"
  echo ""
  echo "Use Support.Stubs instead"
  echo ""

  exit 1
fi
