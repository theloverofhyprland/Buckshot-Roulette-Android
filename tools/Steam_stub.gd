extends Node

# Steam-free replacement for the native Steam singleton.
# Implements every method/constant the game scripts use, so nothing crashes
# when the Steam module is absent (Android / itch build).

signal join_requested(lobby_id: int, friend_id: int)
signal lobby_chat_update(lobby_id: int, changed_id: int, making_change_id: int, chat_state: int)
signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int, permissions: int, locked: bool)
signal lobby_match_list(lobbies: Array)
signal persona_state_change(steam_id: int, change_flag: int)
signal p2p_session_request(steam_id: int)
signal p2p_session_connect_fail(steam_id: int, error: int)
signal avatar_loaded(steam_id: int, size: int, avatar_data: PackedByteArray)
signal leaderboard_find_result(handle: int, found: int)
signal leaderboard_score_uploaded(success: int, handle: int, score: int)
signal leaderboard_scores_downloaded(message: String, handle: int, result: Array)

const LOBBY_TYPE_PRIVATE := 0
const LOBBY_TYPE_FRIENDS_ONLY := 1
const LOBBY_TYPE_PUBLIC := 2
const LOBBY_TYPE_INVISIBLE := 3
const LOBBY_DISTANCE_FILTER_CLOSE := 0
const LOBBY_DISTANCE_FILTER_DEFAULT := 1
const LOBBY_DISTANCE_FILTER_FAR := 2
const LOBBY_DISTANCE_FILTER_WORLDWIDE := 3
const P2P_SEND_UNRELIABLE := 0
const P2P_SEND_UNRELIABLE_NO_DELAY := 1
const P2P_SEND_RELIABLE := 2
const P2P_SEND_RELIABLE_WITH_BUFFERING := 3
const LEADERBOARD_DATA_REQUEST_GLOBAL := 0
const LEADERBOARD_DATA_REQUEST_GLOBAL_AROUND_USER := 1
const LEADERBOARD_DATA_REQUEST_FRIENDS := 2
const LEADERBOARD_UPLOAD_KEEP_BEST := 0
const LEADERBOARD_UPLOAD_FORCE_UPDATE := 1
const CHAT_MEMBER_STATE_CHANGE_ENTERED := 1
const CHAT_MEMBER_STATE_CHANGE_LEFT := 2
const CHAT_MEMBER_STATE_CHANGE_DISCONNECTED := 4
const CHAT_MEMBER_STATE_CHANGE_KICKED := 8
const CHAT_MEMBER_STATE_CHANGE_BANNED := 16
const CHAT_ROOM_ENTER_RESPONSE_SUCCESS := 1
const CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST := 2
const CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED := 3
const CHAT_ROOM_ENTER_RESPONSE_FULL := 4
const CHAT_ROOM_ENTER_RESPONSE_ERROR := 5
const CHAT_ROOM_ENTER_RESPONSE_BANNED := 6
const CHAT_ROOM_ENTER_RESPONSE_LIMITED := 7
const CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED := 8
const CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN := 9
const CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU := 10
const CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER := 11

var appid: int = 2835570
const PACKET_READ_LIMIT: int = 32

var DATA
var LOBBY_ID = 0
var LOBBY_MEMBERS = []
var USER_ID_LIST_TO_IGNORE: Array[int]
var LOBBY_INVITE_ARG = false
var STEAM_ID = 0
var STEAM_NAME = ""
var ONLINE = false
var HOST_ID = 0

var is_lobby_friends_only = true
var lobby_player_limit = 4

var _fake_id: int = 76561198000000000
var _lobby_data: Dictionary = {}

func _ready():
	process_priority = 1000
	set_process_internal(true)
	InitializeSteam()
	ONLINE = false
	STEAM_ID = getSteamID()
	STEAM_NAME = getPersonaName()
	if GlobalVariables.mp_debugging: STEAM_ID = 1234
	print("online ... ", ONLINE, " ... steam id ... ", STEAM_ID, " ... steam name ... ", STEAM_NAME)

func _process(_delta: float) -> void:
	run_callbacks()

func InitializeSteam():
	if GlobalVariables.using_steam:
		OS.set_environment("SteamAppId", str(appid))
		OS.set_environment("SteamGameId", str(appid))
		var INIT: Dictionary = steamInit(false)
		print("steam init: ", str(INIT))
	else:
		print("steam not initialized - not running steam version")

# ---- Steamworks (stubbed) ----
func steamInit(_app_id: bool = false) -> Dictionary: return {"status": 0, "verbal": false}
func run_callbacks() -> void: pass
func loggedOn() -> bool: return false
func getSteamID() -> int: return _fake_id
func getPersonaName() -> String: return "Player"
func getFriendPersonaName(_id: int) -> String: return "Player"
func isSteamRunningOnSteamDeck() -> bool: return false
func getPlayerAvatar(_size: int, _id: int) -> void: pass

func setAchievement(_name: String) -> bool: return true
func clearAchievement(_name: String) -> bool: return true
func storeStats() -> bool: return true

func requestLobbyList() -> void: pass
func addRequestLobbyListDistanceFilter(_f: int) -> void: pass
func addRequestLobbyListResultCountFilter(_n: int) -> void: pass
func createLobby(_type: int, _limit: int) -> void:
	LOBBY_ID = _fake_id
	_lobby_data = {}
func joinLobby(_id: int) -> void: LOBBY_ID = _id
func leaveLobby(_id: int) -> void: LOBBY_ID = 0
func getNumLobbyMembers(_id: int) -> int: return 1
func getLobbyMemberByIndex(_id: int, _idx: int) -> int: return STEAM_ID
func getLobbyOwner(_id: int) -> int: return STEAM_ID
func getLobbyData(_id: int, key: String) -> String: return str(_lobby_data.get(key, ""))
func setLobbyData(_id: int, key: String, value: String) -> bool:
	_lobby_data[key] = value
	return true
func setLobbyJoinable(_id: int, _joinable: bool) -> bool: return true
func setLobbyMemberLimit(_id: int, _limit: int) -> bool: return true
func setLobbyType(_id: int, _type: int) -> bool: return true
func activateGameOverlayInviteDialog(_id: int) -> void: pass

func sendP2PPacket(_id: int, _data: PackedByteArray, _type: int, _channel: int) -> bool: return true
func getAvailableP2PPacketSize(_channel: int) -> int: return 0
func readP2PPacket(_size: int, _channel: int) -> Dictionary: return {}
func acceptP2PSessionWithUser(_id: int) -> bool: return true
func closeP2PSessionWithUser(_id: int) -> void: pass
func allowP2PPacketRelay(_allow: bool) -> bool: return true

func findLeaderboard(_name: String) -> void: pass
func setLeaderboardDetailsMax(_n: int) -> void: pass
func getLeaderboardEntryCount(_handle: int) -> int: return 0
func downloadLeaderboardEntries(_handle: int, _type: int, _start: int, _end: int) -> void: pass
func uploadLeaderboardScore(_handle: int, _method: int, _score: int, _details: Array = []) -> void: pass
