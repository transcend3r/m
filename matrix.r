REBOL [
   Author: "Ingo Hohmann"
   Title: "Matrix Bot"
   Date: 2016-01-30
   Version: 0.0.0.1
]

;
; Imports
;

do <json>
;do %uuid.r
;do %json.reb
;do %prot-http.r

;
; Settings Handling
;

default-server: make object! [
   protocol: https://
   server: "matrix.org"
   port: 8448
   path: %/_matrix/client/
   version: %r0/
   base: function [][
      to-url rejoin [ to-string protocol server ":" port path ]
   ]
   full: function [][
      to-url rejoin [ to-string protocol server ":" port path version]
   ]
   conn: _
]

my-server: make default-server []

my: make object! [
   user: "@testme:matrix.org"
   pass: ""
   token: "QHRlc3RtZTptYXRyaXgub3Jn.kOpspgsnNBdnIXSZfP"
]

test-room: "%21VKZjWusvPdFeAhmlnl%3Amatrix.org"
test-room: "%21sdBclWpGyTPptqNBlR%3A0pt.pw"
test-room: "!sdBclWpGyTPptqNBlR:0pt.pw!FEapnDYVDcfWvNkrDY:matrix.org!FEapnDYVDcfWvNkrDY:matrix.org'"
test-room: "!FEapnDYVDcfWvNkrDY%3Amatrix.org" 
test-room: at http://!FEapnDYVDcfWvNkrDY:matrix.org 8
test-room: "!FEapnDYVDcfWvNkrDY:matrix.org" 


;
; Helpers from my library.
;

dbg: function [
   "print data, and then return it, what ?? did before"
   :v
][
   ;if word? v [prin join v ": " v: get v]
   either binary? v [
      print :v
   ][
      print mold :v
   ]
   :v
]

error-to-obj: function [
   "Create an object from an error"
   error
][
   ;obj: object [code: type: id: message: near: where: arg1: arg2: __FILE__: __LINE__: _]
   ;set obj values-of error
   obj: object* words of error values of error
   dump obj
   if block? obj/message [
      obj/message: spaced bind obj/message obj
   ]
   obj
]

object*: function [
    "Create an object based on some words and values."
    keys [any-word! block!] "Word or block of words"
    values [block!] "Value or block of values"
    object:
][
    object: make object! either block? keys [length? keys] [1]
    bind/new keys object
    set words of object values
    object
]

ref: function [
   "If word is true, return the word, _ otherwise. For use in refinement propagation."
   'word
][
   all [:word word]
]

default*: enfix func [
    "Set word or path to a default value if it is not set yet or blank."

    return: [any-value!]
    :target [set-word! set-path!]
        "The word"
    value [any-value!] ; not <opt> on purpose
        "Value to set (blocks and 0-arity functions evaluated)"
    <local>
        gotten
][
    ; A lookback quoting function that quotes a SET-WORD! on its left is
    ; responsible for setting the value if it wants it to change since the
    ; SET-WORD! is not actually active.  But if something *looks* like an
    ; assignment, it's good practice to evaluate the whole expression to
    ; the result the SET-WORD! was set to, so `x: y: op z` makes `x = y`.
    ;
    any [
        | get target
        | set* target if* true :value ;-- executed if block or function
    ]
]

add-shortcut: function [
   "Add a console shortcut"
   'word [word!]
   code [block!]
][
   extend system/console/shortcuts word code
]

menu: function [
   "create a menu for often used functions"
   'input [<...>]
   /add
   label
   code
   i: n:
   <static> m (copy [])
][
   if add [
      append m label append/only m code
   ] else [
      i: 1
      for-each [l c] m [
         print [i "^-" l]
         i: i + 1
      ]
      trap/with [
         n: to integer! ask "Input number: "
         do m/(n * 2)
      ][|]
   ]
]

add-shortcut .m [menu]

;
; Shortcuts for testing
;

add-shortcut .l [do %matrix.r]
add-shortcut .sfr [sync/filter/raw]

menu/add "reload matrix.r (.l)" [do %matrix.r]
menu/add "sync/filter/raw (.sfr)" [sync/filter/raw]
;
; Internal Helpers
;

txnid: function[
   "Just generate a uuid as txnid"
][
   uuid/to-string uuid/generate
]

login-json: function [
   "Create json for login data"
   username pass
][
   to-json object [type: "m.login.password" user: username password: pass]
]

msg-json: function [
   message
][
   to-json object [msgtype: "m.text" body: message]
]

escape-json: function [
   "Escape characters for JSON"
   s[string!]
][
   replace/all s "\" "\\"
   replace/all s "^/" "\n"
   replace/all s {"} {\"}
   replace/all s "/" "\/"
   replace/all s "^-" "\t"
   s
]

escape-url: function [
   "escape special characters in URLs"
   s
][
   replace/all s "!" "%21"
   replace/all s ":" "%3A"
   s
]

build-reply: function [
   "Create object from json return, adding a wrapped status vlaue"
   ok? [logic!]
   json [string! binary!]
][
   make object [ok: ok? val: from-json json]
]

check-response: function [
   "Check response value for error"
   response [binary! string!]
   <with> json resp-str
][
   json: load-json resp-str: to-string/astral response #"_"
   make object! [ok?: void? :json/error data: json]
]

api: function [
   "Build api url"
   path [any-string! block!]
   /post post-data
   /put put-data
   /no-token
   /raw-path
      base-path
   /with
      url-part
   /raw
   <with> raw-return
][
   if block? path [
      path: rejoin path
   ]
   base-path: default [my-server/full]
   either with [
      url: rejoin [base-path path "?" either no-token [url-part][rejoin ["access_token=" my/token "&" url-part]]]
   ][
      url: rejoin [base-path path either no-token [""][rejoin ["?access_token=" my/token]]]
   ]
   probe url
   ;probe url: compose [scheme: 'https host: 'matrix.org port-id: 8448 path: %_matrix/client/ target: (path)]
   if error? resp: trap [
      raw-return: case [
         post [write url compose [POST [content-type: "application/json"] (post-data)]]
         put  [write url compose [PUT  [content-type: "application/json"] (put-data)]]
         true [write url compose [GET  [content-type: "application/json"] ""]]
      ]
      ret: either raw [raw-return][check-response raw-return]
   ][
      ret: to-json make object! [ok?: false errcode: "M_SERVER_ERROR" error: error-to-obj resp]
   ]
   ;print resp
   ret
]





;
; Api functions
;

versions: function [
   "Get supported spec versions"
][
   api/raw-path/no-token %versions my-server/base
]

login: function [
   "send login"
   user pass
   <with> reply raw-json
][
   reply: probe api/post/no-token %login login-json user pass <|
   if reply/ok? [
      my/token: reply/data/access_token
      my/user:  reply/data/user_id
   ]
]

sync: function [
   /filter
   /raw
   <with> reply raw-json
][
   reply: either filter [
      api/with/(all [raw 'raw]) %sync
      "timeout=3000&filter={'room':{'timeline':{'limit':1,'types':['m.room.message']},'state':{'limit':1,'not_types':['*']},'ephemeral':{'limit':0,'not_types':['*']}},'presence':{'limit':0,'not_types':['*']}}"
   ][
      api/(all [raw 'raw]) %sync
   ]
]

send: function [
   room
   message
   <with> reply raw-json
][
   room: default [test-room]
   message: default ["Hello World!"]
   ;url: rejoin [my-server/full %rooms/ test-room "/send/m.room.message/" uuid "?access_token=" my/token]
   reply: api/put [%rooms/ room "/send/m.room.message/" txnid] probe msg-json message
]




; https://localhost:8448/_matrix/client/r0/sync?filter={'room':{'timeline':{'limit':1}}}


{
help system/script
help system/script/header
help system/script/parent
help system/Options/module-paths
help system/Options/args
}
halt

