// MTSGJ_ChatGPT (Assitant AI) for OpenSimulator v1.4.3
//

//string  hello_message = "Hi, I am ";
//string  stop_message  = "Bye";
//string  uname_message = "user name is ";
//string  wait1_message = "Please wait a moment.";
//string  wait2_message = "Please wait a little longer.";
//string  wait3_message = "It is taking time.";
//integer say_bufsize   = 1020;    // for ASCII

string  hello_message = "こんにちは．私は";
string  stop_message  = "バイバイ";
string  uname_message = "ユーザの名前は";
string  wait1_message = "少々おまちください．";
string  wait2_message = "もうしばらくおまちください．";
string  wait3_message = "時間が掛かっています．";
integer say_bufsize   = 320;       // for Japanese UTF-8. 1023バイト以下での UTF-8(日本語3Byte) の文字数

// ChatGPT API のエンドポイント
string  api_url = "https://api.openai.com/v1/chat/completions";


//
// ChatGPT API の変数
string  api_key = "";
string  api_model = "";
string  api_chara = "";

float   gap_time   = 4.0;     // 解答に時間が掛かる場合のギャップ
integer time_count = 0;
integer listen_hdl = 0;
integer command_channel = 0;  // コマンド受信用チャンネル


// ChatGPT API の JSON データのテンプレート．記載されていないパラメータはデフォルト値 
string  json_templ = "{
  \"model\": \"\",
  \"user\": \"\",
  \"messages\":[
     {
       \"role\": \"system\",
       \"content\": \"\"
     },
    {
       \"role\": \"user\",
       \"content\": \"\"
     }
  ],
  \"stream\": false 
}";


//
key    user_key  = NULL_KEY;
key    npc_key   = NULL_KEY;
string user_name = "";
string npc_name  = "";


/////////////////////////////////////////////////////////////////////////////////
// Note Card 処理
//
// read_basic_notecards()
// read_charactor_notecard()
//


string  chara_notecard_name  = "ChatGPT_Charactor";
string  model_notecard_name  = "ChatGPT_Model";
string  gptkey_notecard_name = "ChatGPT_API_Key";

key     chara_notecard_key  = NULL_KEY;
key     model_notecard_key  = NULL_KEY;
key     gptkey_notecard_key = NULL_KEY;

integer chara_notecard_line  = 0;
integer model_notecard_line  = 0;
integer gptkey_notecard_line = 0;

string  chara_notecard  = "";
string  model_notecard  = "";
string  gptkey_notecard = "";


// 基本設定（key, model）用ノートカードを読み込む
read_basic_notecards()
{
    model_notecard_line  = 0;
    gptkey_notecard_line = 0;
    
    model_notecard  = "";
    gptkey_notecard = "";
    
    gptkey_notecard_key = read_notecard_first(gptkey_notecard_name);
    model_notecard_key  = read_notecard_first(model_notecard_name);
}


// ロール（役割）用の charactor ノートカードを読み込む
read_charactor_notecard()
{
    chara_notecard_line  = 0;    
    chara_notecard  = "";   

    chara_notecard_key  = read_notecard_first(chara_notecard_name);
}


// ノートカードから最初の一行を読み込む
key read_notecard_first(string notecard_name)
{
    if (llGetInventoryType(notecard_name)==INVENTORY_NOTECARD) {
        key notecard_key = llGetNotecardLine(notecard_name, 0);
        return notecard_key;
    }
    return NULL_KEY;
}



/////////////////////////////////////////////////////////////////////////////////
// ChatGPT 処理
//
// request_gpt_api(string _message
//

// ChatGPTの　APIに _messageを送信する．
request_gpt_api(string _message)
{
    string _json_body = "";
    _json_body = llJsonSetValue(json_templ, ["model"], api_model);
    _json_body = llJsonSetValue(_json_body, ["user"],  user_key);
    _json_body = llJsonSetValue(_json_body, ["messages", 0, "content"], api_chara);
    _json_body = llJsonSetValue(_json_body, ["messages", 1, "content"], _message);
    //llSay(0, _json_body);
    
    llHTTPRequest(api_url, 
        [
            HTTP_MIMETYPE, "application/json",
            HTTP_METHOD, "POST",
            HTTP_BODY_MAXLENGTH, 16384,
            //HTTP_ACCEPT, "application/json",
            HTTP_CUSTOM_HEADER, "Authorization", "Bearer " + api_key
        ],
        _json_body
    );
}



/////////////////////////////////////////////////////////////////////////////////
// 会話処理
//
// start_conversation(string _name)
// stop_conversation()
//

start_conversation(string _name)
{
    //llSay(0, "Start Conversation");
    request_gpt_api(hello_message + _name);
    llListen(0, "", NULL_KEY, "");
}


short_conversation(string _message)
{
    if (npc_key == NULL_KEY) {
        if (user_key != NULL_KEY) llRegionSayTo(user_key, 0, _message);
    }
    else {
        osNpcSayTo(npc_key, user_key, 0, _message);
    }
}


stop_conversation()
{
    short_conversation(stop_message);
}


/////////////////////////////////////////////////////////////////////////////////
// 補助関数

// 初期化
init_state()
{
    //llSay( 0, "NSL ChatGPT Running");
    llSetTimerEvent(0);
    llResetTime();
    
    read_basic_notecards();
    
    if (command_channel != 0) {
        if (listen_hdl!=0) llListenRemove(listen_hdl);
        listen_hdl = llListen(command_channel, "", NULL_KEY, "");
        //llSay(0, "init_state: listen Channel = " + command_channel);
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
    }
    
    
    state_entry()
    {
        init_state();
    }
  
   
    touch_start(integer _num_detected)
    {
        user_key  = llDetectedKey(0);
        user_name = llDetectedName(0);
        npc_key   = NULL_KEY;
        read_charactor_notecard();          // touch start の場合は，自前の Chara設定を使用
        //
        start_conversation(user_name);
    }


    listen(integer _ch, string _name, key _id, string _message)
    {
        // from Controller
        if (_ch != 0 && _ch == command_channel) {
            list   _items = llParseString2List(_message, [" "], []);
            integer _len  = llGetListLength(_items);
            string  _cmd  = llList2String(_items, 0);
            //
            // start コマンド : start user_key npc_key [user_fname user_lname npc_fname, npc_lname]
            if (llToLower(_cmd) == "start") {
                if (_len > 3) {
                    user_key  = llList2String(_items, 1);
                    npc_key   = llList2String(_items, 2);
                    if (_len > 3) user_name  = llList2String(_items, 3);
                    if (_len > 4) user_name += " " + llList2String(_items, 4); 
                    if (_len > 5) npc_name   = llList2String(_items, 5);
                    if (_len > 6) npc_name  += " " + llList2String(_items, 6); 
                    start_conversation(user_name);
                }
            }
            // role コマンド : role  role_message
            else if (llToLower(_cmd) == "role") {
                if (_len > 1) {
                    api_chara = "";
                    for (integer i = 1; i < _len; i++) {
                        api_chara += _items[i];
                    }
                    if (user_name != "") api_chara += "\n" + uname_message + user_name;
                    //llSay(0, api_chara);              
                }
            }
            // stop コマンド
            else if (llToLower(_cmd) == "stop") {
                stop_conversation();
                llDie();
            }
        }
        
        // from User
        else if (_id == user_key) {
            //llSay(0, _message);
            request_gpt_api(_message);
            //
            llSetTimerEvent(gap_time);
            llResetTime();
            time_count = 0;
        }
    } 


    changed(integer _change)
    {
        if (_change & CHANGED_INVENTORY) {
            //llSay(0, "Reread NoteCards");
            read_basic_notecards();
        }
    }


    // ノートカードが一行読まれる度に発生するイベント
    dataserver(key _requested_key, string _data)
    {
        // GPT Charactor
        if (_requested_key == chara_notecard_key) {
            if (_data != EOF){
                if (llStringLength(_data) > 0) {
                    if (_data[0] != '#') {
                        list _items = llParseString2List(_data, [" "], []);
                        integer _item_num = llGetListLength(_items);
                        if (_item_num > 0) {             
                            chara_notecard += _data + "\n";
                        }
                    }
                }
                chara_notecard_line++;
                chara_notecard_key = llGetNotecardLine(chara_notecard_name, chara_notecard_line);
            }
            else {
                api_chara = chara_notecard;
            }
        }
        
        // GPT API キー
        else if (_requested_key == gptkey_notecard_key) {
            if (_data != EOF){
                if (llStringLength(_data) > 0) {
                    if (_data[0] != '#') {
                        list _items = llParseString2List(_data, [" "], []);
                        integer _item_num = llGetListLength(_items);
                        if (_item_num > 0) { 
                            gptkey_notecard += _data;
                        }
                    }
                }
                gptkey_notecard_line++;
                gptkey_notecard_key = llGetNotecardLine(gptkey_notecard_name, gptkey_notecard_line);
            }
            else {
                api_key = gptkey_notecard;
            }
        }
        
        // GPT API Model
        else if (_requested_key == model_notecard_key ) {
            if (_data != EOF){
                if (llStringLength(_data) > 0) {
                    if (_data[0] != '#') {
                        list _items = llParseString2List(_data, [" "], []);
                        integer _item_num = llGetListLength(_items);
                        if (_item_num > 0) {
                            model_notecard += _data;
                        }
                    }
                }
                model_notecard_line++;
                model_notecard_key = llGetNotecardLine(model_notecard_name, model_notecard_line);
            }
            else {
                api_model = model_notecard;
            }
        }
    }


    http_response(key _request_id, integer _status, list _metadata, string _body)
    {
        llSetTimerEvent(0);
        time_count = 0;
        //
        if (_status == 200) {
            string _content = llJsonGetValue(_body, ["choices", 0, "message", "content"]);
            //llSay(0, "BODY SIZE = " + llStringLength(_body));
            //llSay(0, "CONTENT SIZE = " + llStringLength(_content));
            //llSay(0, "Data = " + _body);
            
            if (npc_key == NULL_KEY) {
                for (integer p=0; p<llStringLength(_content); p+=say_bufsize) {
                    llRegionSayTo(user_key, 0, llGetSubString(_content, p, p+say_bufsize-1));
                }
            }
            else {
                for (integer p=0; p<llStringLength(_content); p+=say_bufsize) {
                    osNpcSayTo(npc_key, user_key, 0, llGetSubString(_content, p, p+say_bufsize-1));
                }
            }
        }
        // エラー応答
        else {
            if (npc_key == NULL_KEY) {
                llRegionSayTo(user_key, 0, "Request Failure: " + (string)_status + ", Message: " + _body);
            }
            else {
                osNpcSayTo(npc_key, user_key, 0, "Request Failure: " + (string)_status + ", Message: " + _body);
            }
        }
    }
    
    
    timer()
    {
        if      (time_count==0) short_conversation(wait1_message);
        else if (time_count==2) short_conversation(wait2_message);
        else if (time_count==5) short_conversation(wait3_message);
        time_count++;
    }
}
