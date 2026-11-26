#!/usr/bin/env bash
# Chay SAU khi `npm start` dang chay o terminal khac, va VUA KHOI DONG LAI server
# (bo dem rate limit nam trong bo nho; khoi dong lai de ve 0).
# Dung: bash test-bai4.sh [url]   (mac dinh http://localhost:3000)
B=${1:-http://localhost:3000}
J='Content-Type: application/json'
st() { curl -s -o /tmp/r4.json -w "%{http_code}" "$@"; }
tok() { curl -s -X POST $B/auth/login -H "$J" -d "{\"email\":\"$1\",\"password\":\"$2\"}" | node -pe "JSON.parse(require('fs').readFileSync(0)).token"; }

echo "== Xac thuc =="
echo "register sv1 (201 hoac 409 neu da co)  -> $(st -X POST $B/auth/register -H "$J" -d '{"email":"sv1@tdmu.edu.vn","password":"matkhau123"}')"
echo "register sv2 (201 hoac 409 neu da co)  -> $(st -X POST $B/auth/register -H "$J" -d '{"email":"sv2@tdmu.edu.vn","password":"matkhau456"}')"
T1=$(tok sv1@tdmu.edu.vn matkhau123); T2=$(tok sv2@tdmu.edu.vn matkhau456)
echo "token sv1 dai ${#T1} ky tu, token sv2 dai ${#T2} ky tu (phai > 100)"
echo "GET /notes khong token (401)           -> $(st $B/notes)"
echo "GET /notes co token sv1 (200)          -> $(st $B/notes -H "Authorization: Bearer $T1")"
echo "login gui doi tuong (401)              -> $(st -X POST $B/auth/login -H "$J" -d '{"email":{"$gt":""},"password":"x"}')"; cat /tmp/r4.json; echo

echo "== Kiem soat truy cap theo chu so huu =="
echo "sv1 tao ghi chu (201)                  -> $(st -X POST $B/notes -H "$J" -H "Authorization: Bearer $T1" -d '{"title":"Ghi chú riêng của sv1","tags":["bai4"]}')"
ID=$(node -pe "JSON.parse(require('fs').readFileSync('/tmp/r4.json','utf8'))._id")
echo "sv1 doc ghi chu cua minh (200)         -> $(st $B/notes/$ID -H "Authorization: Bearer $T1")"
echo "sv2 doc ghi chu cua sv1 (404, khong 403)-> $(st $B/notes/$ID -H "Authorization: Bearer $T2")"
echo "sv2 sua ghi chu cua sv1 (404)          -> $(st -X PUT $B/notes/$ID -H "$J" -H "Authorization: Bearer $T2" -d '{"title":"hack"}')"
echo "sv2 xoa ghi chu cua sv1 (404)          -> $(st -X DELETE $B/notes/$ID -H "Authorization: Bearer $T2")"
echo "sv1 xoa ghi chu cua minh (204)         -> $(st -X DELETE $B/notes/$ID -H "Authorization: Bearer $T1")"

echo "== Rate limit: 25 lan dang nhap sai =="
echo "(da dung ~6 request /auth o tren, nen 429 se xuat hien som hon lan thu 21;"
echo " muon dung 'lan thu 21', khoi dong lai server roi chay rieng doan vong lap)"
for i in $(seq 1 25); do curl -s -o /dev/null -w "%{http_code} " -X POST $B/auth/login -H "$J" -d '{"email":"a@b.cc","password":"saimatkhau"}'; done; echo
