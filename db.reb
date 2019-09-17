REBOL []
db: make object! [
  set: js-native [k v]{localStorage.setItem(reb.T(reb.Arg("k")), reb.Arg("v"))}
  get: js-native [k]{localStorage.getItem(reb.T(reb.Arg("k")))}
]
