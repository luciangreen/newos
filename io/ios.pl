% 200 inputs and outputs, from real runs: io(N, Predicate, Inputs, Output).
io(1,conversation,[["Why?","Who is mortal?","Is Socrates happy?","The moon is not cheese."]],["Why what? Ask me a question first, and then ask why.","I don't know anyone or anything that is mortal. (\"mortal\" means certain to die some day.)","I don't know whether socrates is happy. Tell me and I'll remember.","OK, I'll remember that: The moon is not cheese."]).
io(2,spec_open,[["file1",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["ABC 123"]).
io(3,spec_save,[["a b","I see it."]],["I see it."]).
io(4,spec_navigate,[["folder2",["folder1",["file1","file2"]],["folder2",["file4"]]]],["file4"]).
io(5,spec_search,[[d,[a,a,a,a,a,a]]],["Error."]).
io(6,conversation,[["The moon is not cheese."]],["Got it: The moon is not cheese."]).
io(7,spec_open,[["file2",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["hedgehogs"]).
io(8,spec_save,[["file1","I can feel it."]],["I can feel it."]).
io(9,spec_navigate,[["folder3",["folder2",["file1","file2","file3"]]]],["Error"]).
io(10,spec_search,[[a,[b]]],["Error."]).
io(11,conversation,[["Who likes Mary?","What does John like?"]],["I don't know who likes mary.","I don't know what john does like."]).
io(12,spec_open,[["file3",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["I like you."]).
io(13,spec_save,[["notes","A"]],["A"]).
io(14,spec_navigate,[["folder1",["folder4",["x"]]]],["Error"]).
io(15,spec_search,[[b,[c,c]]],["Error."]).
io(16,conversation,[["Tweety is a bird.","Can Tweety fly?","What is 6*7?"]],["OK, I'll remember that: Tweety is a bird.","I don't know whether Tweety can fly. Tell me and I'll remember.","6*7 = 42."]).
io(17,spec_open,[["file4",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["Error."]).
io(18,spec_save,[["",""]],["Error."]).
io(19,spec_navigate,[["folder2",["folder2",["file1","file2","file3"]]]],["file1","file2","file3"]).
io(20,spec_search,[[c,[d,d,d]]],["Error."]).
io(21,conversation,[["2+2=5","My name is Lucian."]],["Actually, 2+2 = 4, not 5.","Nice to meet you, Lucian."]).
io(22,spec_open,[["",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["Error."]).
io(23,spec_save,[["a b","Two. Sentences."]],["Two. Sentences."]).
io(24,spec_navigate,[["folder3",["folder4",["x"]]]],["Error"]).
io(25,spec_search,[[d,[e,e,e,e]]],["Error."]).
io(26,conversation,[["If the moon is cheese, then 2+2=4.","use relevance logic","All cheese is edible."]],["Something went wrong (error(type_error(lambda_free,f(moon is cheese,eq(2+2,4))),_G)). Could you put it another way?","Now reading \"if\" with the relevance logic. \"If A then B\" needs A and B to share content, and B to follow from A.","I've learned that All cheeses are edible."]).
io(27,spec_open,[["file4",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["Error."]).
io(28,spec_save,[["file1","I see it."]],["I see it."]).
io(29,spec_navigate,[["folder1",["folder1",["file1","file2"]],["folder2",["file4"]]]],["file1","file2"]).
io(30,spec_search,[[a,[b,c,d,e,a]]],[a]).
io(31,conversation,[["What is 12/4?","Plato is a man.","Is Plato mortal?","Socrates is a man."]],["12/4 = 3.","Got it: Plato is a man.","I don't know whether Plato is mortal. Tell me and I'll remember.","I've learned that Socrates is a man."]).
io(32,spec_open,[["",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["Error."]).
io(33,spec_save,[["notes","I can feel it."]],["I can feel it."]).
io(34,spec_navigate,[["folder2",["folder4",["x"]]]],["Error"]).
io(35,spec_search,[[b,[c,d,e,a,b,c]]],[b,c]).
io(36,conversation,[["Socrates is a man."]],["OK, I'll remember that: Socrates is a man."]).
io(37,spec_open,[["file1",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["ABC 123"]).
io(38,spec_save,[["","A"]],["Error."]).
io(39,spec_navigate,[["folder3",["folder1",["file1","file2"]],["folder2",["file4"]]]],["Error"]).
io(40,spec_search,[[c,[d]]],["Error."]).
io(41,conversation,[["Why?","Who is mortal?","Is Socrates happy?","The moon is not cheese."]],["Why what? Ask me a question first, and then ask why.","I don't know anyone or anything that is mortal. (\"mortal\" means certain to die some day.)","I don't know whether socrates is happy. Tell me and I'll remember.","OK, I'll remember that: The moon is not cheese."]).
io(42,spec_open,[["file2",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["hedgehogs"]).
io(43,spec_save,[["a b",""]],[""]).
io(44,spec_navigate,[["folder1",["folder2",["file1","file2","file3"]]]],["Error"]).
io(45,spec_search,[[d,[e,a]]],["Error."]).
io(46,conversation,[["The moon is not cheese."]],["Got it: The moon is not cheese."]).
io(47,spec_open,[["file3",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["I like you."]).
io(48,spec_save,[["file1","Two. Sentences."]],["Two. Sentences."]).
io(49,spec_navigate,[["folder2",["folder1",["file1","file2"]],["folder2",["file4"]]]],["file4"]).
io(50,spec_search,[[a,[a,b,c]]],[a,b,c]).
io(51,conversation,[["Who likes Mary?","What does John like?"]],["I don't know who likes mary.","I don't know what john does like."]).
io(52,spec_open,[["file2",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["hedgehogs"]).
io(53,spec_save,[["notes","I see it."]],["I see it."]).
io(54,spec_navigate,[["folder3",["folder2",["file1","file2","file3"]]]],["Error"]).
io(55,spec_search,[[b,[c,e,b,d]]],[b,d]).
io(56,conversation,[["Tweety is a bird.","Can Tweety fly?","What is 6*7?"]],["OK, I'll remember that: Tweety is a bird.","I don't know whether Tweety can fly. Tell me and I'll remember.","6*7 = 42."]).
io(57,spec_open,[["file3",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["I like you."]).
io(58,spec_save,[["","I can feel it."]],["Error."]).
io(59,spec_navigate,[["folder1",["folder4",["x"]]]],["Error"]).
io(60,spec_search,[[c,[d,a,c,e,b]]],[c,e,b]).
io(61,conversation,[["2+2=5","My name is Lucian."]],["Actually, 2+2 = 4, not 5.","Nice to meet you, Lucian."]).
io(62,spec_open,[["file4",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["Error."]).
io(63,spec_save,[["a b","A"]],["A"]).
io(64,spec_navigate,[["folder2",["folder2",["file1","file2","file3"]]]],["file1","file2","file3"]).
io(65,spec_search,[[d,[e,b,d,a,c,e]]],[d,a,c,e]).
io(66,conversation,[["If the moon is cheese, then 2+2=4.","use relevance logic","All cheese is edible."]],["Something went wrong (error(type_error(lambda_free,f(moon is cheese,eq(2+2,4))),_G)). Could you put it another way?","Now reading \"if\" with the relevance logic. \"If A then B\" needs A and B to share content, and B to follow from A.","I've learned that All cheeses are edible."]).
io(67,spec_open,[["",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["Error."]).
io(68,spec_save,[["file1",""]],[""]).
io(69,spec_navigate,[["folder3",["folder4",["x"]]]],["Error"]).
io(70,spec_search,[[a,[a]]],[a]).
io(71,conversation,[["What is 12/4?","Plato is a man.","Is Plato mortal?","Socrates is a man."]],["12/4 = 3.","Got it: Plato is a man.","I don't know whether Plato is mortal. Tell me and I'll remember.","I've learned that Socrates is a man."]).
io(72,spec_open,[["file1",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["ABC 123"]).
io(73,spec_save,[["notes","Two. Sentences."]],["Two. Sentences."]).
io(74,spec_navigate,[["folder1",["folder1",["file1","file2"]],["folder2",["file4"]]]],["file1","file2"]).
io(75,spec_search,[[b,[b,d]]],[b,d]).
io(76,conversation,[["Socrates is a man."]],["OK, I'll remember that: Socrates is a man."]).
io(77,spec_open,[["",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["Error."]).
io(78,spec_save,[["","I see it."]],["Error."]).
io(79,spec_navigate,[["folder2",["folder4",["x"]]]],["Error"]).
io(80,spec_search,[[c,[d,b,e]]],["Error."]).
io(81,conversation,[["Why?","Who is mortal?","Is Socrates happy?","The moon is not cheese."]],["Why what? Ask me a question first, and then ask why.","I don't know anyone or anything that is mortal. (\"mortal\" means certain to die some day.)","I don't know whether socrates is happy. Tell me and I'll remember.","OK, I'll remember that: The moon is not cheese."]).
io(82,spec_open,[["file1",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["ABC 123"]).
io(83,spec_save,[["a b","I can feel it."]],["I can feel it."]).
io(84,spec_navigate,[["folder3",["folder1",["file1","file2"]],["folder2",["file4"]]]],["Error"]).
io(85,spec_search,[[d,[e,c,a,d]]],[d]).
io(86,conversation,[["The moon is not cheese."]],["Got it: The moon is not cheese."]).
io(87,spec_open,[["file2",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["hedgehogs"]).
io(88,spec_save,[["file1","A"]],["A"]).
io(89,spec_navigate,[["folder1",["folder2",["file1","file2","file3"]]]],["Error"]).
io(90,spec_search,[[a,[a,d,b,e,c]]],[a,d,b,e,c]).
io(91,conversation,[["Who likes Mary?","What does John like?"]],["I don't know who likes mary.","I don't know what john does like."]).
io(92,spec_open,[["file3",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["I like you."]).
io(93,spec_save,[["notes",""]],[""]).
io(94,spec_navigate,[["folder2",["folder1",["file1","file2"]],["folder2",["file4"]]]],["file4"]).
io(95,spec_search,[[b,[b,e,c,a,d,b]]],[b,e,c,a,d,b]).
io(96,conversation,[["Tweety is a bird.","Can Tweety fly?","What is 6*7?"]],["OK, I'll remember that: Tweety is a bird.","I don't know whether Tweety can fly. Tell me and I'll remember.","6*7 = 42."]).
io(97,spec_open,[["file4",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["Error."]).
io(98,spec_save,[["","Two. Sentences."]],["Error."]).
io(99,spec_navigate,[["folder3",["folder2",["file1","file2","file3"]]]],["Error"]).
io(100,spec_search,[[c,[c]]],[c]).
io(101,conversation,[["2+2=5","My name is Lucian."]],["Actually, 2+2 = 4, not 5.","Nice to meet you, Lucian."]).
io(102,spec_open,[["file3",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["I like you."]).
io(103,spec_save,[["a b","I see it."]],["I see it."]).
io(104,spec_navigate,[["folder1",["folder4",["x"]]]],["Error"]).
io(105,spec_search,[[d,[e,d]]],[d]).
io(106,conversation,[["If the moon is cheese, then 2+2=4.","use relevance logic","All cheese is edible."]],["Something went wrong (error(type_error(lambda_free,f(moon is cheese,eq(2+2,4))),_G)). Could you put it another way?","Now reading \"if\" with the relevance logic. \"If A then B\" needs A and B to share content, and B to follow from A.","I've learned that All cheeses are edible."]).
io(107,spec_open,[["file4",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["Error."]).
io(108,spec_save,[["file1","I can feel it."]],["I can feel it."]).
io(109,spec_navigate,[["folder2",["folder2",["file1","file2","file3"]]]],["file1","file2","file3"]).
io(110,spec_search,[[a,[a,e,d]]],[a,e,d]).
io(111,conversation,[["What is 12/4?","Plato is a man.","Is Plato mortal?","Socrates is a man."]],["12/4 = 3.","Got it: Plato is a man.","I don't know whether Plato is mortal. Tell me and I'll remember.","I've learned that Socrates is a man."]).
io(112,spec_open,[["",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["Error."]).
io(113,spec_save,[["notes","A"]],["A"]).
io(114,spec_navigate,[["folder3",["folder4",["x"]]]],["Error"]).
io(115,spec_search,[[b,[b,a,e,d]]],[b,a,e,d]).
io(116,conversation,[["Socrates is a man."]],["OK, I'll remember that: Socrates is a man."]).
io(117,spec_open,[["file1",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["ABC 123"]).
io(118,spec_save,[["",""]],["Error."]).
io(119,spec_navigate,[["folder1",["folder1",["file1","file2"]],["folder2",["file4"]]]],["file1","file2"]).
io(120,spec_search,[[c,[c,b,a,e,d]]],[c,b,a,e,d]).
io(121,conversation,[["Why?","Who is mortal?","Is Socrates happy?","The moon is not cheese."]],["Why what? Ask me a question first, and then ask why.","I don't know anyone or anything that is mortal. (\"mortal\" means certain to die some day.)","I don't know whether socrates is happy. Tell me and I'll remember.","OK, I'll remember that: The moon is not cheese."]).
io(122,spec_open,[["file2",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["hedgehogs"]).
io(123,spec_save,[["a b","Two. Sentences."]],["Two. Sentences."]).
io(124,spec_navigate,[["folder2",["folder4",["x"]]]],["Error"]).
io(125,spec_search,[[d,[d,c,b,a,e,d]]],[d,c,b,a,e,d]).
io(126,conversation,[["The moon is not cheese."]],["Got it: The moon is not cheese."]).
io(127,spec_open,[["file1",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["ABC 123"]).
io(128,spec_save,[["file1","I see it."]],["I see it."]).
io(129,spec_navigate,[["folder3",["folder1",["file1","file2"]],["folder2",["file4"]]]],["Error"]).
io(130,spec_search,[[a,[a]]],[a]).
io(131,conversation,[["Who likes Mary?","What does John like?"]],["I don't know who likes mary.","I don't know what john does like."]).
io(132,spec_open,[["file2",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["hedgehogs"]).
io(133,spec_save,[["notes","I can feel it."]],["I can feel it."]).
io(134,spec_navigate,[["folder1",["folder2",["file1","file2","file3"]]]],["Error"]).
io(135,spec_search,[[b,[b,b]]],[b,b]).
io(136,conversation,[["Tweety is a bird.","Can Tweety fly?","What is 6*7?"]],["OK, I'll remember that: Tweety is a bird.","I don't know whether Tweety can fly. Tell me and I'll remember.","6*7 = 42."]).
io(137,spec_open,[["file3",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["I like you."]).
io(138,spec_save,[["","A"]],["Error."]).
io(139,spec_navigate,[["folder2",["folder1",["file1","file2"]],["folder2",["file4"]]]],["file4"]).
io(140,spec_search,[[c,[c,c,c]]],[c,c,c]).
io(141,conversation,[["2+2=5","My name is Lucian."]],["Actually, 2+2 = 4, not 5.","Nice to meet you, Lucian."]).
io(142,spec_open,[["file4",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["Error."]).
io(143,spec_save,[["a b",""]],[""]).
io(144,spec_navigate,[["folder3",["folder2",["file1","file2","file3"]]]],["Error"]).
io(145,spec_search,[[d,[d,d,d,d]]],[d,d,d,d]).
io(146,conversation,[["If the moon is cheese, then 2+2=4.","use relevance logic","All cheese is edible."]],["Something went wrong (error(type_error(lambda_free,f(moon is cheese,eq(2+2,4))),_G)). Could you put it another way?","Now reading \"if\" with the relevance logic. \"If A then B\" needs A and B to share content, and B to follow from A.","I've learned that All cheeses are edible."]).
io(147,spec_open,[["",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["Error."]).
io(148,spec_save,[["file1","Two. Sentences."]],["Two. Sentences."]).
io(149,spec_navigate,[["folder1",["folder4",["x"]]]],["Error"]).
io(150,spec_search,[[a,[e,e,e,e,e]]],["Error."]).
io(151,conversation,[["What is 12/4?","Plato is a man.","Is Plato mortal?","Socrates is a man."]],["12/4 = 3.","Got it: Plato is a man.","I don't know whether Plato is mortal. Tell me and I'll remember.","I've learned that Socrates is a man."]).
io(152,spec_open,[["file4",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["Error."]).
io(153,spec_save,[["notes","I see it."]],["I see it."]).
io(154,spec_navigate,[["folder2",["folder2",["file1","file2","file3"]]]],["file1","file2","file3"]).
io(155,spec_search,[[b,[b,c,d,e,a,b]]],[b,c,d,e,a,b]).
io(156,conversation,[["Socrates is a man."]],["OK, I'll remember that: Socrates is a man."]).
io(157,spec_open,[["",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["Error."]).
io(158,spec_save,[["","I can feel it."]],["Error."]).
io(159,spec_navigate,[["folder3",["folder4",["x"]]]],["Error"]).
io(160,spec_search,[[c,[c]]],[c]).
io(161,conversation,[["Why?","Who is mortal?","Is Socrates happy?","The moon is not cheese."]],["Why what? Ask me a question first, and then ask why.","I don't know anyone or anything that is mortal. (\"mortal\" means certain to die some day.)","I don't know whether socrates is happy. Tell me and I'll remember.","OK, I'll remember that: The moon is not cheese."]).
io(162,spec_open,[["file1",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["ABC 123"]).
io(163,spec_save,[["a b","A"]],["A"]).
io(164,spec_navigate,[["folder1",["folder1",["file1","file2"]],["folder2",["file4"]]]],["file1","file2"]).
io(165,spec_search,[[d,[d,e]]],[d,e]).
io(166,conversation,[["The moon is not cheese."]],["Got it: The moon is not cheese."]).
io(167,spec_open,[["file2",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["hedgehogs"]).
io(168,spec_save,[["file1",""]],[""]).
io(169,spec_navigate,[["folder2",["folder4",["x"]]]],["Error"]).
io(170,spec_search,[[a,[e,a,b]]],[a,b]).
io(171,conversation,[["Who likes Mary?","What does John like?"]],["I don't know who likes mary.","I don't know what john does like."]).
io(172,spec_open,[["file3",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["I like you."]).
io(173,spec_save,[["notes","Two. Sentences."]],["Two. Sentences."]).
io(174,spec_navigate,[["folder3",["folder1",["file1","file2"]],["folder2",["file4"]]]],["Error"]).
io(175,spec_search,[[b,[a,b,c,d]]],[b,c,d]).
io(176,conversation,[["Tweety is a bird.","Can Tweety fly?","What is 6*7?"]],["OK, I'll remember that: Tweety is a bird.","I don't know whether Tweety can fly. Tell me and I'll remember.","6*7 = 42."]).
io(177,spec_open,[["file2",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["hedgehogs"]).
io(178,spec_save,[["","I see it."]],["Error."]).
io(179,spec_navigate,[["folder1",["folder2",["file1","file2","file3"]]]],["Error"]).
io(180,spec_search,[[c,[c,e,b,d,a]]],[c,e,b,d,a]).
io(181,conversation,[["2+2=5","My name is Lucian."]],["Actually, 2+2 = 4, not 5.","Nice to meet you, Lucian."]).
io(182,spec_open,[["file3",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["I like you."]).
io(183,spec_save,[["a b","I can feel it."]],["I can feel it."]).
io(184,spec_navigate,[["folder2",["folder1",["file1","file2"]],["folder2",["file4"]]]],["file4"]).
io(185,spec_search,[[d,[d,a,c,e,b,d]]],[d,a,c,e,b,d]).
io(186,conversation,[["If the moon is cheese, then 2+2=4.","use relevance logic","All cheese is edible."]],["Something went wrong (error(type_error(lambda_free,f(moon is cheese,eq(2+2,4))),_G)). Could you put it another way?","Now reading \"if\" with the relevance logic. \"If A then B\" needs A and B to share content, and B to follow from A.","I've learned that All cheeses are edible."]).
io(187,spec_open,[["file4",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["Error."]).
io(188,spec_save,[["file1","A"]],["A"]).
io(189,spec_navigate,[["folder3",["folder2",["file1","file2","file3"]]]],["Error"]).
io(190,spec_search,[[a,[e]]],["Error."]).
io(191,conversation,[["What is 12/4?","Plato is a man.","Is Plato mortal?","Socrates is a man."]],["12/4 = 3.","Got it: Plato is a man.","I don't know whether Plato is mortal. Tell me and I'll remember.","I've learned that Socrates is a man."]).
io(192,spec_open,[["",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["Error."]).
io(193,spec_save,[["notes",""]],[""]).
io(194,spec_navigate,[["folder1",["folder4",["x"]]]],["Error"]).
io(195,spec_search,[[b,[a,c]]],["Error."]).
io(196,conversation,[["Socrates is a man."]],["OK, I'll remember that: Socrates is a man."]).
io(197,spec_open,[["file1",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]],["ABC 123"]).
io(198,spec_save,[["","Two. Sentences."]],["Error."]).
io(199,spec_navigate,[["folder2",["folder2",["file1","file2","file3"]]]],["file1","file2","file3"]).
io(200,spec_search,[[c,[b,d,a]]],["Error."]).
