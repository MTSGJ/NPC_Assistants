// NPC_Assistant v1.4.3
//   support MTSGJ_ChatCPT is over v1.4.3
//

// デフォルト
string  assist_ai = "NSL_ChatGTP";
string  appear_name = "Appearance_Normal";

//string  objfar_message = "Too far away from the object, please approach within 10 meters.";
string  objfar_message = "オブジェクトから離れすぎています．10m 以内に近づいてください．";

string  fname = "NPC";
string  lname = "";
string  charactor_desc = "";

// Listen
integer recv_channel = 683;  // 受信用チャンネル（固定）
integer send_channel = 684;  // 送信用チャンネルの開始番号



/////////////////////////////////////////////////////////////////////////////////
// Note Card 処理
//
// 設定用ノートカード（_Config）は先頭から以下の順で記述する．
//
// 1. 送信チャンネルの開始番号．（１行）
// 2. Assistant AI オブジェクトの名前．（１行）
// 3. NPCの名前．（ファーストネーム，空白，ラストネーム．１行）
// 4. NPCのアピアランス ファイル名．（１行）
// 5. NPCのロール（複数行．ファイルの最期まで）
// 
// 空行（または半角空白のみの行）は無視される．行の先頭が #の場合は，その行は無視される．
// 
// read_config_notecard()
// read_notecard_first(string notecard_name): key
// proc_config_notecard(string _line)
//

// Note Cards
string  config_notecard_name = "_Config";  // 設定用ノートカード
    
key     config_notecard_key  = NULL_KEY;
string  config_notecard      = "";
integer config_notecard_line = 0;
integer config_notecard_num  = 0;


// 設定用 ノートカードを読み込む
read_config_notecard()
{
    charactor_desc = "";
    //
    config_notecard_line = 0;
    config_notecard  = "";
    config_notecard_key = read_notecard_first(config_notecard_name);
}


// ノートカードの最初の一行を読む
key read_notecard_first(string notecard_name)
{
   if (llGetInventoryType(notecard_name)==INVENTORY_NOTECARD) {
       key notecard_key = llGetNotecardLine(notecard_name, 0);
       return notecard_key;
   }
   return NULL_KEY;
}


// 読み込んだ行を処理する．
proc_config_notecard(string _line)
{
    //llSay(0, _line);
    if (llStringLength(_line) > 0) {
        if (_line[0] != '#') {
            list _items = llParseString2List(_line, [" "], []);
            integer _item_num = llGetListLength(_items);
            //
            if (_item_num > 0) {
                if (config_notecard_num == 0) {         // No.1
                    send_channel = (integer)_items[0];
                }
                else if (config_notecard_num == 1) {    // No.2
                    assist_ai = _items[0];
                }
                else if (config_notecard_num == 2) {    // No.3
                    fname = _items[0];
                    lname = "";
                    if (_item_num>1) lname = _items[1];
                }
                else if (config_notecard_num == 3) {    // No.4
                    appear_name = _items[0];
                }
                else {                                  // No.5
                    charactor_desc += _line + "\n";
                }
                config_notecard_num++;
            }
        }
    }
    //
    config_notecard_line++;
    config_notecard_key = llGetNotecardLine(config_notecard_name, config_notecard_line);
}



/////////////////////////////////////////////////////////////////////////////////
// NPC List用関数
// 
// npc_list は [user_key, npc_key, channel] の繰り返し
//
// check_user_list(key _user_key): integer
// check_npc_list(key _npc_key): integer
// check_channel_list(integer _channel): integer
// get_valid_channel(): integer
//

integer list_stride = 3;    // npc_list の一組の要素数
list npc_list = [];         // [user_key, npc_key, channel] の繰り返し


// 指定したユーザがリストにあるかどうかをチェックする．
//   ユーザが存在する場合は，npc_list中のデータの先頭の位置を返す．
//   ユーザが存在しない場合は -1 を返す．
integer check_user_list(key _user_key)
{
    integer _indx = 0;
    integer _len = llGetListLength(npc_list);
    
    for(_indx=0; _indx<_len; _indx+=list_stride) {
        if (_user_key == (key)npc_list[_indx]) {
            return _indx;
        }
    } 
    return -1;
}


// 指定したNPCがリストにあるかどうかをチェックする．
//   NPCが存在する場合は，npc_list中のデータの先頭位置を返す．
//   NPCが存在しない場合は -1 を返す．
integer check_npc_list(key _npc_key)
{
    integer _indx = 0;
    integer _len = llGetListLength(npc_list);
    
    for(_indx=0; _indx<_len; _indx+=list_stride) {
        if (_npc_key == (key)npc_list[_indx + 1]) {
            return _indx;
        }
    } 
    return -1;
}


// 指定したチャンネル番号がリストにあるかどうかをチェックする．
//   チャンネル番号が存在する場合は，npc_list中のデータの先頭位置を返す．
//   チャンネル番号が存在しない場合は -1 を返す．
integer check_channel_list(integer _channel)
{
    integer _indx = 0;
    integer _len = llGetListLength(npc_list);
    
    for(_indx=0; _indx<_len; _indx+=list_stride) {
        if (_channel == (integer)npc_list[_indx + 2]) {
            return _indx;
        }
    } 
    return -1;
}


// send_channel 以上の有効なチャンネル番号を返す．
integer get_valid_channel()
{
    integer _channel = send_channel;
    
    integer _indx = check_channel_list(_channel);
    while (_indx != -1) {
        _channel++;
        _indx = check_channel_list(_channel);
    }   
    return _channel;
}



/////////////////////////////////////////////////////////////////////////////////
// NPC と Assistant AIオブジェクト
//
// key create_npc(key _user_key, vector _user_pos)
// delete_all_npc()
//

// NPC の作成と Assistant AIオブジェクトのRez
key create_npc(key _user_key, vector _user_pos)
{
    vector _obj_pos = llGetPos();
    vector _move_to = _user_pos - llVecNorm(_user_pos - _obj_pos)*1.5;                 // 1.5m 手前
    vector _rezz_at = _user_pos - llVecNorm(_user_pos - _obj_pos) + <0.0, 0.0, -1.0>;  // 1.0m 手前．1.0m 下方（タッチされないように）
    float  _dist = llVecDist(_obj_pos, _rezz_at);

    key _npc_key = NULL_KEY;
    if (_dist < 10.0) {
        // NPC 作成
        _npc_key = osNpcCreate(fname, lname, _obj_pos, appear_name, OS_NPC_SENSE_AS_AGENT);
        osNpcMoveTo(_npc_key, _move_to);
        // Assistant AIオブジェクトの Rez
        integer _channel = get_valid_channel();  // 未使用のチャンネルを得る
        llRezObject(assist_ai, _rezz_at, <0.0, 0.0, 0.0>, <0.0, 0.0, 0.0, 1.0>, _channel);
        // NPCリストに登録
        npc_list = npc_list + [_user_key, _npc_key, _channel];
    }
    else {
        llRegionSayTo(_user_key, 0, objfar_message);
    }
    return _npc_key;
}


delete_npc(integer _indx)
{
    key     _npc_key = (key)npc_list[_indx + 1];
    integer _channel = (integer)npc_list[_indx + 2];
    llWhisper(_channel, "stop");
    llSleep(1.0);                  // NPC に挨拶させるため
    osNpcRemove(_npc_key);
}
            
            
// 全てのNPC, Assist AIオブジェクトと NPCリストを削除
delete_all_npc()
{
    integer _len = llGetListLength(npc_list);
    integer _indx = 0;
    for (_indx=0; _indx<_len; _indx += list_stride) {
        delete_npc(_indx);
    }
    npc_list = [];
}



/////////////////////////////////////////////////////////////////////////////////
// 補助関数

integer listen_hdl = 0;

// 初期化
init_script()
{
    delete_all_npc();
    //
    llResetScript();
    
    if (listen_hdl!=0) llListenRemove(listen_hdl);
    listen_hdl = llListen(recv_channel, "", NULL_KEY, "");
    
    read_config_notecard();
}



////////////////////////////////////////////////////////////////////////////////////////////

default
{
    state_entry()
    {
        //llSay(0, "Script running");
        init_script();
    }
    
    
    touch_start(integer _number)
    {
        key    _user_key  = llDetectedKey(0);
        string _user_name = llDetectedName(0);
        vector _user_pos  = llDetectedPos(0);
        
        integer _indx = check_user_list(_user_key);
        
        if (_indx==-1) {
            // NPC と Assistant AIオブジェクトを起動
            key _npc_key = create_npc(_user_key, _user_pos);
            llSleep(1.0);
            //
            integer _num = check_npc_list(_npc_key);
            if (_num>=0) {
                // Assistant AIオブジェクトにコマンドを送信する
                integer _channel = (integer)npc_list[_num + 2];
                string  _command = "start " + _user_key + " " + _npc_key + " " + _user_name + " " + fname + " " + lname;
                llWhisper(_channel, _command);
                if (charactor_desc != "") {
                    _command = "role " + charactor_desc;
                    llWhisper(_channel, _command);
                }      
            }
        }
        // 既にNPCを起動している場合は，NPC と Assistant AIオブジェクトを削除
        else if (_indx>=0) {
            delete_npc(_indx);
            npc_list = llListReplaceList(npc_list, [], _indx, _indx + list_stride - 1); // リストから削除
        }
    }
    
    
    listen(integer _ch, string _name, key _id, string _msg) 
    {
        llSay(0, "Recived Message: " + _msg);        
        list _items = llParseString2List(_msg, ["=", ",", " ", "\n"], []);       
        string _cmd = llList2String(_items, 0);
        string _opr = llList2String(_items, 1);

        if  (_cmd == "" || _cmd == " ") {
            // NOP
        }
        // reset command
        else if (llToLower(_cmd) == "reset") {
            init_script();
        }
        // delete command
        else if (llToLower(_cmd) == "delete" || llToLower(_cmd) == "del") {
            if (_id == llGetOwner()) {
                if (llToLower(_opr) == "all") {
                    delete_all_npc();
                }
                else {
                    key _npc_key = (key)_opr;
                    osNpcRemove(_npc_key);
                    integer _indx = check_npc_list(_npc_key);
                    if (_indx>=0) npc_list = llListReplaceList(npc_list, [], _indx, _indx + list_stride - 1);
                }
            }
        }
    }
    

    // ノートカードが一行読まれる度に発生するイベント
    dataserver(key _requested_key, string _data)
    {
        // Configuration File
        if (_requested_key == config_notecard_key) {
            if (_data != EOF) {
                proc_config_notecard(_data);
            }
        }
    }


    //
    on_rez(integer _start_param) 
    {
        init_script();
    }
   
    
    changed(integer _change)
    {
        //地域が再起動された場合
        if (_change & CHANGED_REGION_START) {
            init_script();
        }
        else if (_change & CHANGED_INVENTORY) {
            init_script();
        }   
    }                
}
