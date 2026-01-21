场景UI转C++代码

=======================
用来快速制作自己的编辑器界面,很多复杂工具还是要在C++里面制作,但是C++拼界面是非常繁琐恶心的事情,不得不用scene来扩展,这样导致工具很难解耦.
新版本已经适配到godot4,但是有一些小改动,需要使用者自己调整.
支持了StyleBox插件,可以给godot制作非常炫酷的界面了,动画还不支持,后期再看看怎么搞.
不过编辑器界面对于动画需求不是那么太紧急.
材质扩展目前支持的也不太好,这个玩意也不太重要.
=======================

This plugin helps you convert any branch of nodes into C++ engine code that can be used to develop the Godot Editor. This is particularly useful for making GUIs, and the plugin was primarily developped towards this goal.

![Screenshot](screenshot.png)


Installation
--------------

This is a regular editor plugin.
Copy the contents of `addons/zylann.scene_code_converter` into the same folder in your project, and activate it in your project settings.


Usage
------

- Open the Godot Editor and open the scene containing the nodes you want to convert
- When the plugin is activated, a new button will appear in the main viewport's toolbar, in `2D` mode.
- Select the root node of the branch you want to convert
- Click the `Convert to engine code` button
- This will open a popup with the generated code. It may be pasted in the constructor of the root node's C++ class, and will build a copy of the selected node and all its children.
- You may want to adjust a few things in the generated code:
	- Names are generated. If you wish to keep some nodes as member variables, you should replace them.
	- It's possible that some of the code is invalid. In that case you may adjust it, and eventually do a PR to fix it, when possible.
	- Sometimes nodes have resources on them like textures, but in engine code resources are handled differently. The plugin currently leaves them out.





