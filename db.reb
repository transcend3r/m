REBOL []
db: make object! [
  set: js-native [k v]{localStorage.setItem(reb.Spell(reb.T(reb.Arg("k"))), reb.Spell(reb.Arg("v")))}
  get: js-native [k]{localStorage.getItem(return reb.T(reb.Arg("k")))}
]
