-module(snapshot).

-compile([export_all/1]).
-include_lib("eunit/include/eunit.hrl").

get_test() ->
  os:cmd("rm -rf test.db"),
  {ok, Db} = rocksdb:open("test.db", [{create_if_missing, true}]),
  try
    rocksdb:put(Db, <<"a">>, <<"x">>, []),
    ?assertEqual({ok, <<"x">>}, rocksdb:get(Db, <<"a">>, [])),
    {ok, Snapshot} = rocksdb:snapshot(Db),
    rocksdb:put(Db, <<"a">>, <<"y">>, []),
    ?assertEqual({ok, <<"y">>}, rocksdb:get(Db, <<"a">>, [])),
    ?assertEqual({ok, <<"x">>}, rocksdb:get(Db, <<"a">>, [{snapshot, Snapshot}])),
    rocksdb:release_snapshot(Snapshot)
  after
    rocksdb:close(Db)
  end.

multiple_snapshot_test() ->
  os:cmd("rm -rf test.db"),
  {ok, Db} = rocksdb:open("test.db", [{create_if_missing, true}]),
  try
    rocksdb:put(Db, <<"a">>, <<"1">>, []),
    ?assertEqual({ok, <<"1">>}, rocksdb:get(Db, <<"a">>, [])),

    {ok, Snapshot} = rocksdb:snapshot(Db),
    rocksdb:put(Db, <<"a">>, <<"2">>, []),
    ?assertEqual({ok, <<"2">>}, rocksdb:get(Db, <<"a">>, [])),
    ?assertEqual({ok, <<"1">>}, rocksdb:get(Db, <<"a">>, [{snapshot, Snapshot}])),

    {ok, Snapshot2} = rocksdb:snapshot(Db),
    rocksdb:put(Db, <<"a">>, <<"3">>, []),
    ?assertEqual({ok, <<"3">>}, rocksdb:get(Db, <<"a">>, [])),
    ?assertEqual({ok, <<"1">>}, rocksdb:get(Db, <<"a">>, [{snapshot, Snapshot}])),
    ?assertEqual({ok, <<"2">>}, rocksdb:get(Db, <<"a">>, [{snapshot, Snapshot2}])),

    {ok, Snapshot3} = rocksdb:snapshot(Db),
    rocksdb:put(Db, <<"a">>, <<"4">>, []),
    ?assertEqual({ok, <<"4">>}, rocksdb:get(Db, <<"a">>, [])),
    ?assertEqual({ok, <<"1">>}, rocksdb:get(Db, <<"a">>, [{snapshot, Snapshot}])),
    ?assertEqual({ok, <<"2">>}, rocksdb:get(Db, <<"a">>, [{snapshot, Snapshot2}])),
    ?assertEqual({ok, <<"3">>}, rocksdb:get(Db, <<"a">>, [{snapshot, Snapshot3}])),

    rocksdb:release_snapshot(Snapshot),
    rocksdb:release_snapshot(Snapshot2),
    rocksdb:release_snapshot(Snapshot3)
  after
    rocksdb:close(Db)
  end.


iterator_test() ->
  os:cmd("rm -rf ltest"),  % NOTE
  {ok, Ref} = rocksdb:open("ltest", [{create_if_missing, true}]),
  try
    rocksdb:put(Ref, <<"a">>, <<"x">>, []),
    rocksdb:put(Ref, <<"b">>, <<"y">>, []),
    {ok, I} = rocksdb:iterator(Ref, []),
    ?assertEqual({ok, <<"a">>, <<"x">>},rocksdb:iterator_move(I, <<>>)),
    ?assertEqual({ok, <<"b">>, <<"y">>},rocksdb:iterator_move(I, next)),
    ?assertEqual({ok, <<"a">>, <<"x">>},rocksdb:iterator_move(I, prev)),

    {ok, Snapshot} = rocksdb:snapshot(Ref),

    rocksdb:put(Ref, <<"b">>, <<"z">>, []),

    {ok, I2} = rocksdb:iterator(Ref, []),
    ?assertEqual({ok, <<"a">>, <<"x">>},rocksdb:iterator_move(I2, <<>>)),
    ?assertEqual({ok, <<"b">>, <<"z">>},rocksdb:iterator_move(I2, next)),
    ?assertEqual({ok, <<"a">>, <<"x">>},rocksdb:iterator_move(I2, prev)),

    {ok, I3} = rocksdb:iterator(Ref, [{snapshot, Snapshot}]),
    ?assertEqual({ok, <<"a">>, <<"x">>},rocksdb:iterator_move(I3, <<>>)),
    ?assertEqual({ok, <<"b">>, <<"y">>},rocksdb:iterator_move(I3, next)),
    ?assertEqual({ok, <<"a">>, <<"x">>},rocksdb:iterator_move(I3, prev)),
    rocksdb:release_snapshot(Snapshot)
  after
    rocksdb:close(Ref)
  end.


release_snapshot_test() ->
  os:cmd("rm -rf ltest"),  % NOTE
  {ok, Ref} = rocksdb:open("ltest", [{create_if_missing, true}]),

  try
    rocksdb:put(Ref, <<"a">>, <<"x">>, []),
    rocksdb:put(Ref, <<"b">>, <<"y">>, []),

    {ok, Snapshot} = rocksdb:snapshot(Ref),

    rocksdb:put(Ref, <<"b">>, <<"z">>, []),

    {ok, I} = rocksdb:iterator(Ref, [{snapshot, Snapshot}]),
    ?assertEqual({ok, <<"a">>, <<"x">>},rocksdb:iterator_move(I, <<>>)),
    ?assertEqual({ok, <<"b">>, <<"y">>},rocksdb:iterator_move(I, next)),
    ok = rocksdb:release_snapshot(Snapshot),
    ?assertEqual({ok, <<"a">>, <<"x">>}, rocksdb:iterator_move(I, prev)),

    %% snapshot has been released, it can't be reused
    ?assertError(badarg, rocksdb:iterator(Ref, [{snapshot, Snapshot}]))

  after
    rocksdb:close(Ref)
  end.


close_iterator_test() ->
  os:cmd("rm -rf ltest"),  % NOTE
  {ok, Ref} = rocksdb:open("ltest", [{create_if_missing, true}]),

  try
    rocksdb:put(Ref, <<"a">>, <<"x">>, []),
    rocksdb:put(Ref, <<"b">>, <<"y">>, []),

    {ok, Snapshot} = rocksdb:snapshot(Ref),

    rocksdb:put(Ref, <<"b">>, <<"z">>, []),

    {ok, I} = rocksdb:iterator(Ref, [{snapshot, Snapshot}]),
    ?assertEqual({ok, <<"a">>, <<"x">>},rocksdb:iterator_move(I, <<>>)),
    ?assertEqual({ok, <<"b">>, <<"y">>},rocksdb:iterator_move(I, next)),

    rocksdb:iterator_close(I),
    rocksdb:release_snapshot(Snapshot)
  after
    rocksdb:close(Ref)
  end.

db_close_test() ->
  os:cmd("rm -rf ltest"),  % NOTE
  {ok, Ref} = rocksdb:open("ltest", [{create_if_missing, true}]),

  rocksdb:put(Ref, <<"a">>, <<"x">>, []),
  rocksdb:put(Ref, <<"b">>, <<"y">>, []),

  {ok, Snapshot} = rocksdb:snapshot(Ref),

  rocksdb:put(Ref, <<"b">>, <<"z">>, []),


  {ok, I} = rocksdb:iterator(Ref, [{snapshot, Snapshot}]),
  ?assertEqual({ok, <<"a">>, <<"x">>},rocksdb:iterator_move(I, <<>>)),
  ?assertEqual({ok, <<"b">>, <<"y">>},rocksdb:iterator_move(I, next)),
  ok = rocksdb:release_snapshot(Snapshot),
  ?assertEqual({ok, <<"a">>, <<"x">>}, rocksdb:iterator_move(I, prev)),

  rocksdb:close(Ref),

  %% snapshot has been released when the db was closed, it can't be reused
  ?assertError(badarg, rocksdb:iterator(Ref, [{snapshot, Snapshot}])),


  os:cmd("rm -rf ltest"),
  {ok, Db} = rocksdb:open("ltest", [{create_if_missing, true}]),
  rocksdb:put(Db, <<"a">>, <<"x">>, []),
  ?assertEqual({ok, <<"x">>}, rocksdb:get(Db, <<"a">>, [])),
  {ok, Snapshot2} = rocksdb:snapshot(Db),
  rocksdb:put(Db, <<"a">>, <<"y">>, []),
  ?assertEqual({ok, <<"x">>}, rocksdb:get(Db, <<"a">>, [{snapshot, Snapshot2}])),
  rocksdb:close(Db),

  %% snapshot has been released when the db was closed, it can't be reused
  ?assertError(badarg, rocksdb:get(Db, <<"a">>, [{snapshot, Snapshot2}])).
