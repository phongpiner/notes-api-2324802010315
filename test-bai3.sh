#!/usr/bin/env bash
# Chay SAU khi `npm start` dang chay o terminal khac. In ma trang thai cua tung thao tac.
B=${1:-http://localhost:3000}
code() { curl -s -o /tmp/resp.json -w "%{http_code}" "$@"; }

echo "1) POST /notes (tao)            -> $(code -X POST $B/notes -H 'Content-Type: application/json' -d '{"title":"Ôn chương 3","content":"HDFS vs GFS","tags":["cloud","nosql"]}')   (mong doi 201)"
ID=$(node -pe "JSON.parse(require('fs').readFileSync('/tmp/resp.json','utf8'))._id")
echo "   _id = $ID"
echo "2) GET /notes?tag=nosql          -> $(code "$B/notes?tag=nosql")   (mong doi 200)"
echo "3) GET /notes/<id>               -> $(code $B/notes/$ID)   (mong doi 200)"
echo "4) PUT /notes/<id>               -> $(code -X PUT $B/notes/$ID -H 'Content-Type: application/json' -d '{"title":"Ôn chương 3 (sửa)","content":"HDFS vs GFS","tags":["cloud"]}')   (mong doi 200)"
echo "Tệp thử" > /tmp/note.txt
echo "5) POST /notes/<id>/attachment   -> $(code -X POST $B/notes/$ID/attachment -F 'file=@/tmp/note.txt')   (mong doi 200)"
echo "   attachmentUrl = $(node -pe "JSON.parse(require('fs').readFileSync('/tmp/resp.json','utf8')).attachmentUrl")"
echo "6) DELETE /notes/<id>            -> $(code -X DELETE $B/notes/$ID)   (mong doi 204)"
echo "7) DELETE lan 2                  -> $(code -X DELETE $B/notes/$ID)   (mong doi 404)"
echo "8) POST thieu title              -> $(code -X POST $B/notes -H 'Content-Type: application/json' -d '{"content":"x"}')   (mong doi 400)"
echo "9) GET /notes/abc (id sai)       -> $(code $B/notes/abc)   (mong doi 400)"
