tmpdir=$(mktemp -d /tmp/lambda-XXXXXX)
zipfile=$tmpdir/lambda.zip
virtualenv=$tmpdir/virtual-env
(
  virtualenv $virtualenv
  source $virtualenv/bin/activate
  sudo pip install awscli boto3
)

# "aws" command (fixing shabang line)
rsync -va $virtualenv/bin/aws $tmpdir/aws
perl -pi -e '$_ ="#!/usr/bin/python\n" if $. == 1' $tmpdir/aws
(cd $tmpdir; zip -r9 $zipfile aws)

# aws-cli package requirements
(cd $virtualenv/lib/python2.7/site-packages && zip -r9 $zipfile *)

# AWS Lambda function (with the right name)
rsync -va lambda_function.py $tmpdir/lambda_function.py
(cd $tmpdir; zip -r9 $zipfile lambda_function.py)
cp $zipfile .
rm -r $tmpdir



