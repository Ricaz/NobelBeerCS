/******/ (function(modules) { // webpackBootstrap
/******/ 	// The module cache
/******/ 	var installedModules = {};
/******/
/******/ 	// The require function
/******/ 	function __webpack_require__(moduleId) {
/******/
/******/ 		// Check if module is in cache
/******/ 		if(installedModules[moduleId]) {
/******/ 			return installedModules[moduleId].exports;
/******/ 		}
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = installedModules[moduleId] = {
/******/ 			i: moduleId,
/******/ 			l: false,
/******/ 			exports: {}
/******/ 		};
/******/
/******/ 		// Execute the module function
/******/ 		modules[moduleId].call(module.exports, module, module.exports, __webpack_require__);
/******/
/******/ 		// Flag the module as loaded
/******/ 		module.l = true;
/******/
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/
/******/
/******/ 	// expose the modules object (__webpack_modules__)
/******/ 	__webpack_require__.m = modules;
/******/
/******/ 	// expose the module cache
/******/ 	__webpack_require__.c = installedModules;
/******/
/******/ 	// define getter function for harmony exports
/******/ 	__webpack_require__.d = function(exports, name, getter) {
/******/ 		if(!__webpack_require__.o(exports, name)) {
/******/ 			Object.defineProperty(exports, name, { enumerable: true, get: getter });
/******/ 		}
/******/ 	};
/******/
/******/ 	// define __esModule on exports
/******/ 	__webpack_require__.r = function(exports) {
/******/ 		if(typeof Symbol !== 'undefined' && Symbol.toStringTag) {
/******/ 			Object.defineProperty(exports, Symbol.toStringTag, { value: 'Module' });
/******/ 		}
/******/ 		Object.defineProperty(exports, '__esModule', { value: true });
/******/ 	};
/******/
/******/ 	// create a fake namespace object
/******/ 	// mode & 1: value is a module id, require it
/******/ 	// mode & 2: merge all properties of value into the ns
/******/ 	// mode & 4: return value when already ns object
/******/ 	// mode & 8|1: behave like require
/******/ 	__webpack_require__.t = function(value, mode) {
/******/ 		if(mode & 1) value = __webpack_require__(value);
/******/ 		if(mode & 8) return value;
/******/ 		if((mode & 4) && typeof value === 'object' && value && value.__esModule) return value;
/******/ 		var ns = Object.create(null);
/******/ 		__webpack_require__.r(ns);
/******/ 		Object.defineProperty(ns, 'default', { enumerable: true, value: value });
/******/ 		if(mode & 2 && typeof value != 'string') for(var key in value) __webpack_require__.d(ns, key, function(key) { return value[key]; }.bind(null, key));
/******/ 		return ns;
/******/ 	};
/******/
/******/ 	// getDefaultExport function for compatibility with non-harmony modules
/******/ 	__webpack_require__.n = function(module) {
/******/ 		var getter = module && module.__esModule ?
/******/ 			function getDefault() { return module['default']; } :
/******/ 			function getModuleExports() { return module; };
/******/ 		__webpack_require__.d(getter, 'a', getter);
/******/ 		return getter;
/******/ 	};
/******/
/******/ 	// Object.prototype.hasOwnProperty.call
/******/ 	__webpack_require__.o = function(object, property) { return Object.prototype.hasOwnProperty.call(object, property); };
/******/
/******/ 	// __webpack_public_path__
/******/ 	__webpack_require__.p = "";
/******/
/******/
/******/ 	// Load entry module and return exports
/******/ 	return __webpack_require__(__webpack_require__.s = "./src/webapp/app.js");
/******/ })
/************************************************************************/
/******/ ({

/***/ "./node_modules/vue-native-websocket/dist/build.js":
/*!*********************************************************!*\
  !*** ./node_modules/vue-native-websocket/dist/build.js ***!
  \*********************************************************/
/*! no static exports found */
/***/ (function(module, exports) {

eval("throw new Error(\"Module build failed: Error: ENOENT: no such file or directory, open '/home/rcz/Development/nodejs/BeerCSpack/node_modules/vue-native-websocket/dist/build.js'\");\n\n//# sourceURL=webpack:///./node_modules/vue-native-websocket/dist/build.js?");

/***/ }),

/***/ "./node_modules/vue/dist/vue.js":
/*!**************************************!*\
  !*** ./node_modules/vue/dist/vue.js ***!
  \**************************************/
/*! no static exports found */
/***/ (function(module, exports) {

eval("throw new Error(\"Module build failed: Error: ENOENT: no such file or directory, open '/home/rcz/Development/nodejs/BeerCSpack/node_modules/vue/dist/vue.js'\");\n\n//# sourceURL=webpack:///./node_modules/vue/dist/vue.js?");

/***/ }),

/***/ "./src/webapp/app.js":
/*!***************************!*\
  !*** ./src/webapp/app.js ***!
  \***************************/
/*! no exports provided */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
eval("__webpack_require__.r(__webpack_exports__);\n/* harmony import */ var vue__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! vue */ \"./node_modules/vue/dist/vue.js\");\n/* harmony import */ var vue__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(vue__WEBPACK_IMPORTED_MODULE_0__);\n/* harmony import */ var vue_native_websocket__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! vue-native-websocket */ \"./node_modules/vue-native-websocket/dist/build.js\");\n/* harmony import */ var vue_native_websocket__WEBPACK_IMPORTED_MODULE_1___default = /*#__PURE__*/__webpack_require__.n(vue_native_websocket__WEBPACK_IMPORTED_MODULE_1__);\n/* harmony import */ var _scoreboard_js__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./scoreboard.js */ \"./src/webapp/scoreboard.js\");\n // import Vuex from 'vuex'\n\n\nvar socketHost = 'ws://localhost:8080';\nvar socketOptions = {\n  protocol: 'beercs',\n  format: 'json',\n  reconnection: true,\n  reconnectionAttemps: 10,\n  reconnectionDelay: 2000\n};\n // Vue.use(Vuex)\n\nvue__WEBPACK_IMPORTED_MODULE_0___default.a.use(vue_native_websocket__WEBPACK_IMPORTED_MODULE_1___default.a, socketHost, socketOptions);\nvar app = new vue__WEBPACK_IMPORTED_MODULE_0___default.a({\n  el: '#app',\n  data: {\n    status: \"connected\",\n    wslog: [],\n    scores: [{\n      name: 'lols',\n      kills: 5,\n      teamkills: 1,\n      knifekills: 1,\n      knifed: 0,\n      sips: 35,\n      rounds: 4\n    }, {\n      name: 'Kaptajn Haddock',\n      kills: 9,\n      teamkills: 0,\n      knifekills: 9,\n      knifed: 0,\n      sips: 49,\n      rounds: 5\n    }, {\n      name: 'KAJANTHAN KAKATARZAN',\n      kills: 0,\n      teamkills: 6,\n      knifekills: 9,\n      knifed: 32,\n      sips: 291,\n      rounds: 19\n    }]\n  },\n  created: function created() {\n    this.$options.sockets.onmessage = this.handleMessage;\n  },\n  methods: {\n    handleMessage: function handleMessage(msg) {\n      var data = JSON.parse(msg.data);\n      console.log('recieved:', data);\n      this.status = data.cmd;\n      this.wslog.push(data);\n      this.playSound(data.playsound);\n\n      switch (data.cmd) {\n        case \"kill\":\n          // scoreboard.handleKill('STEAMID:001', 'STEAMID:002')\n          break;\n\n        case \"round\":\n          //this.playSound()\n          break;\n      }\n    },\n    playSound: function playSound(path) {\n      if (!path) {\n        return;\n      }\n\n      this.$refs.audio.src = path;\n      this.$refs.audio.play();\n    },\n    playVideo: function playVideo(e) {\n      var video = 'videos/' + this.videos[Math.floor(Math.random() * videos.length)];\n      console.log('playing video', video);\n      this.$refs.video.src = video;\n      this.$refs.video.play();\n    }\n  }\n});\n\n//# sourceURL=webpack:///./src/webapp/app.js?");

/***/ }),

/***/ "./src/webapp/scoreboard.js":
/*!**********************************!*\
  !*** ./src/webapp/scoreboard.js ***!
  \**********************************/
/*! exports provided: Scoreboard */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
eval("__webpack_require__.r(__webpack_exports__);\n/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, \"Scoreboard\", function() { return Scoreboard; });\nfunction _defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if (\"value\" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } }\n\nfunction _createClass(Constructor, protoProps, staticProps) { if (protoProps) _defineProperties(Constructor.prototype, protoProps); if (staticProps) _defineProperties(Constructor, staticProps); return Constructor; }\n\nfunction _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError(\"Cannot call a class as a function\"); } }\n\nvar Player = function Player(args) {\n  _classCallCheck(this, Player);\n\n  this.id = args.id;\n  this.name = args.name;\n  this.kills = 0;\n  this.teamkills = 0;\n  this.knifekills = 0;\n  this.knifed = 0;\n  this.sips = 0;\n  this.rounds = 0;\n};\n\nvar Scoreboard =\n/*#__PURE__*/\nfunction () {\n  function Scoreboard(args) {\n    _classCallCheck(this, Scoreboard);\n\n    this.players = [];\n  }\n\n  _createClass(Scoreboard, [{\n    key: \"findPlayer\",\n    value: function findPlayer(steamid) {\n      var found = false;\n      this.players.forEach(function (player) {\n        if (player.steamid === steamid) {\n          return player;\n        }\n      });\n      return false;\n    }\n  }, {\n    key: \"newRound\",\n    value: function newRound() {\n      this.players.forEach(function (player) {\n        this.addSip(player.id);\n        this.addRound(player.id);\n      });\n    }\n  }, {\n    key: \"handleKnife\",\n    value: function handleKnife(killerID, victimID) {\n      killer = this.findPlayer(killerID);\n      victim = this.findPlayer(victimID);\n\n      if (player && victim) {\n        this.addKnife(killer);\n        this.addDeath(victim);\n        this.addKnifed(victim);\n      }\n    }\n  }, {\n    key: \"handleKill\",\n    value: function handleKill(killerID, victimID) {\n      killer = this.findPlayer(killerID);\n      victim = this.findPlayer(victimID);\n\n      if (player && victim) {\n        this.addKill(killer);\n        this.addDeath(victim);\n      }\n    }\n  }, {\n    key: \"addKnifed\",\n    value: function addKnifed(id) {\n      player = this.findPlayer(id);\n      if (player) player.knifed++;\n    }\n  }, {\n    key: \"addDeath\",\n    value: function addDeath(id) {\n      player = this.findPlayer(id);\n      if (player) player.deaths++;\n    }\n  }, {\n    key: \"addKill\",\n    value: function addKill(steamid) {\n      var args = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : [];\n      player = this.findPlayer(steamid);\n      if (player) player.kills++;\n    }\n  }, {\n    key: \"addPlayer\",\n    value: function addPlayer(args) {\n      var player = new Player(id, name);\n      this.players.push(player);\n    }\n  }, {\n    key: \"reset\",\n    value: function reset() {\n      this.players.forEach(function (player) {\n        player.kills = 0;\n        player.teamkills = 0;\n        player.knifekills = 0;\n        player.knifed = 0;\n        player.sips = 0;\n        player.rounds = 0;\n      });\n    }\n  }]);\n\n  return Scoreboard;\n}();\n\n//# sourceURL=webpack:///./src/webapp/scoreboard.js?");

/***/ })

/******/ });