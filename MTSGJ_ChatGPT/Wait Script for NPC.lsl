// Wait Script for NPC Assistant v1.0.2
//    
// NPC Assistant の待機時間を指定する．
// NPC Assistant から Rezされた場合，指定した待機時間内に入力が無いときは，
// メッセージ出力（stop_conversation実行）後にオブジェクト（含む NPC）を破棄する．
//
// このオブジェクトにタッチした場合は，local_mode となり，待機時間は無効になる．
// 

float  wait_time  = 180.0;   // 待機時間（s）
//string bye_message = "Since there seem to be no questions, I will return."
string bye_message = "何も質問が無いようですので，一旦戻ります．";

//
integer command_channel = 0;  // コマンド受信用チャンネル
integer listen_hdl = 0;
integer local_mode = 0;

//
key    user_key  = NULL_KEY;
key    npc_key   = NULL_KEY;
string user_name = "";
string npc_name  = "";


/////////////////////////////////////////////////////////////////////////////////
// 会話処理
//
// short_conversation(string _message)
//

short_conversation(string _message)
{
    if (npc_key == NULL_KEY) {
        if (user_key !=NULL_KEY) llRegionSayTo(user_key, 0, _message);
    }
    else {
        osNpcSayTo(npc_key, user_key, 0, _message);
    }
}



/////////////////////////////////////////////////////////////////////////////////
// 補助関数

// 初期化
init_state()
{
    llSetTimerEvent(0);
    llResetTime();
    local_mode = 0;
    
    if (command_channel != 0) {
        if (listen_hdl!=0) llListenRemove(listen_hdl);
        listen_hdl = llListen(command_channel, "", NULL_KEY, "");
    }
}



//////////////////////////////////////////////////////////////////////////////////////////////////////

default
{
    on_rez(integer _param)
    {
        command_channel = _param;
        if (command_channel != 0) {
            if (listen_hdl!=0) llListenRemove(listen_hdl);
            listen_hdl = llListen(command_channel, "", NULL_KEY, "");
            //llSay(0, "on_rez: listen Channel = " + command_channel);
        }
        //
        if (local_mode == 0) {
            llSetTimerEvent(wait_time);
            llResetTime();
        }
    }
    
    
    state_entry()
    {
        init_state();
        llListen(0, "", NULL_KEY, "");
    }

    
    touch_start(integer _num)
    {
        local_mode = 1;       // ローカルモードの場合は，待機機能なし．
        llSetTimerEvent(0);
        llResetTime();
    }


    listen(integer _ch, string _name, key _id, string _message)
    {
        // from Controller
        if (_ch != 0 && _ch == command_channel) {
            list   _items = llParseString2List(_message, [" "], []);
            integer _len  = llGetListLength(_items);
            string  _cmd  = llList2String(_items, 0);
            //
            // start コマンド : start user_key npc_key [user_fname user_lname npc_fname npc_lname]
            if (llToLower(_cmd) == "start") {
                if (_len > 3) {
                    user_key  = llList2String(_items, 1);
                    npc_key   = llList2String(_items, 2);
                    if (_len > 3) user_name  = llList2String(_items, 3);
                    if (_len > 4) user_name += " " + llList2String(_items, 4);
                    if (_len > 5) npc_name   = llList2String(_items, 5);
                    if (_len > 6) npc_name  += " " + llList2String(_items, 6);
                    local_mode = 0;
                }
            }   
        }
        // from User
        else if (_id == user_key) {
            if (local_mode == 0) {
                llSetTimerEvent(wait_time);   // 待機時間をリセット
                llResetTime();
            }
        }
    } 


    changed(integer _change)
    {
        if (_change & CHANGED_INVENTORY) {
            init_state();
        }
    }
    
    
    timer()
    {
        if (local_mode == 0) {
            // 待機時間切れ
            short_conversation(bye_message);
            if (npc_key != NULL_KEY) {
                llSleep(1.0);
                osNpcRemove(npc_key);
            }
            llDie();
        }
    }
}
