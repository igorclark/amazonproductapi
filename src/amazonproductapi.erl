-module(amazonproductapi).

-include_lib("amazonproductapi/include/amazonproductapi.hrl").

-export([
         itemSearch/2,
         itemSearch/3,
         itemLookup/3
        ]).

-define(PROTOCOL, "http").
-define(REQUEST_URI, "/onca/xml").


-spec itemSearch(string(), #amazonproductapi_config{}) -> {ok, list()}.
itemSearch(Keywords, Config) ->
    itemSearch(Keywords, 1, Config).

-spec itemSearch(string(), integer(), #amazonproductapi_config{}) -> {ok, list()}.
itemSearch(Keywords, ItemPage, Config) ->
    do_rest_call(get, "ItemSearch", [{"Keywords", Keywords}, {"ItemPage", integer_to_list(ItemPage)}], Config).

-spec itemLookup(string(), string(), #amazonproductapi_config{}) -> {ok, list()}.
itemLookup(IdType, ItemId, Config) ->
    do_rest_call(get, "ItemLookup", [{"IdType", IdType}, {"ItemId", ItemId}], Config).



do_rest_call(RequestMethod, Operation, Params, Config) ->

    %% See: http://associates-amazon.s3.amazonaws.com/scratchpad/index.html
    
    AllParams = [{"Operation", Operation},
                   {"Service", "AWSECommerceService"},
                   {"AWSAccessKeyId", Config#amazonproductapi_config.access_key},
                   {"AssociateTag", Config#amazonproductapi_config.associate_tag},
                   {"Version", "2011-08-01"},
                   {"SearchIndex", "All"},
                   {"Condition", "All"},
                   {"ResponseGroup", "Images,ItemAttributes,Offers"},
                   {"Timestamp", make_date()}
                 | Params],
    EncodedAndSortedParams = lists:sort([{K, z_url:percent_encode(V)} || {K, V} <- AllParams]),

    StringedParams = string:join([K ++ "=" ++ V || {K, V} <- EncodedAndSortedParams], "&"),
    
    SignString = map_request_method(RequestMethod) ++ "\n"
        ++  Config#amazonproductapi_config.endpoint ++ "\n"
        ++ ?REQUEST_URI ++ "\n"
        ++ StringedParams,

    Signature = z_url:percent_encode(z_convert:to_list(base64:encode(hmac:hmac256(Config#amazonproductapi_config.secret, SignString)))),

    Url = ?PROTOCOL ++ "://" ++ Config#amazonproductapi_config.endpoint ++ ?REQUEST_URI ++ "?"
        ++ StringedParams ++ "&Signature=" ++ Signature,

    case httpc:request(RequestMethod, {Url, []}, [], []) of
        {ok, {{_, 200, _}, _ResponseHeaders, Body}} ->
			{ok, parsexml:parse(list_to_binary(Body))};
        {ok, {{_, OtherCode, _}, _ResponseHeaders, Body}} ->
            {error,
			 {http, OtherCode, parsexml:parse(list_to_binary(Body))}};
        {error, R} ->
            {error, R}
    end.

map_request_method(get) -> "GET";
map_request_method(post) -> "POST".

make_date() ->
    z_convert:to_list(z_dateformat:format(calendar:local_time(), "c", [])).
                    
