// x86unity's stand-in engine, Frameworks/UnityFramework.framework/UnityFramework: NOT Unity. It exports the part of
// IL2CPP's embedding API (il2cpp_*) that simax's Unity reader (host/simax/simax_unity.m) uses, over a tiny object model
// laid out as IL2CPP lays out objects (header, boxed values after it, strings' UTF-16 at +20, arrays' elements at +32),
// and a UnityView that draws its "game" with layers and takes touches. The scene, in a screen space overlay canvas:
//   Button "Play" (text child "Play": a tap adds one to the score), Toggle "Sound" (on), Slider "Volume" (0.25 of 0..1),
//   InputField "Name" (placeholder "Your name"; a tap focuses it), Text "Score: 0", Text "Name: ... ended N" (onEndEdit
//   count), and a game object "Player" with a renderer (seen through Camera.main), "Ghost" (inactive: never listed).
// X86UNITY_STRIPPED=1: Object.FindObjectsByType / FindObjectsOfType are missing (code stripping); SceneManager and the
// transform walk are there (the reader's fallback). Every touch / text change is logged as an X86TEST line.
#import <UIKit/UIKit.h>
#include <stdlib.h>
#include <string.h>

// an X86TEST line (stderr and Documents/x86test-results.txt, as tests/apps/common.swift writes them)
static void x86unity_log(const char* check, const char* detail) {
	NSString* l = [NSString stringWithFormat:@"X86TEST x86unity %s PASS %s\n", check, detail ?: ""];
	fputs(l.UTF8String, stderr);
	NSString* f = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject
		stringByAppendingPathComponent:@"x86test-results.txt"];
	NSFileHandle* h = [NSFileHandle fileHandleForWritingAtPath:f];
	if (!h) {
		[l writeToFile:f atomically:NO encoding:NSUTF8StringEncoding error:nil];
		return;
	}
	[h seekToEndOfFile];
	[h writeData:[l dataUsingEncoding:NSUTF8StringEncoding]];
	[h closeFile];
}

typedef struct Klass Klass;
typedef struct Obj { Klass* klass; void* monitor; } Obj;
typedef Obj* (*Fn)(Obj* self, void** args);
typedef struct { Klass* k; } IType;
typedef struct Method { const char* name; int argc; const char* p0; Fn fn; Klass* owner; int is_static; } Method;
struct Klass {
	const char* ns;
	const char* name;
	Klass* parent;
	Method methods[16];
	int nm;
	int valuetype, size;   // size: of a boxed value
	IType type;
};

#define MAXK 48
static Klass K[MAXK];
static int nk;
static int g_stripped;

static Klass* defk(const char* ns, const char* name, Klass* parent) {
	Klass* k = &K[nk++];
	k->ns = ns, k->name = name, k->parent = parent, k->type.k = k;
	return k;
}
static void defm(Klass* k, const char* name, int argc, const char* p0, Fn fn, int st) {
	k->methods[k->nm++] = (Method){ name, argc, p0, fn, k, st };
}

static Obj* alloc(Klass* k, size_t sz) {
	Obj* o = calloc(1, sz < 16 ? 16 : sz);
	o->klass = k;
	return o;
}

// -- core types
static Klass *kObject, *kComponent, *kBehaviour, *kGameObject, *kTransform, *kRectTransform, *kCanvas, *kCamera, *kScreen,
	*kVector3, *kRenderer, *kSelectable, *kButton, *kToggle, *kSlider, *kInputField, *kGraphic, *kText, *kString, *kInt,
	*kBool, *kFloat, *kType, *kBounds, *kEvent, *kSceneManager, *kScene, *kArray;

static Obj* box(Klass* k, const void* v, size_t n) {
	Obj* o = alloc(k, 16 + n);
	memcpy((char*)o + 16, v, n);
	return o;
}
static Obj* box_i(int32_t v) { return box(kInt, &v, 4); }
static Obj* box_b(int v) { uint8_t b = v != 0; return box(kBool, &b, 1); }
static Obj* box_f(float v) { return box(kFloat, &v, 4); }

static Obj* mkstr(const char* s) {
	NSString* n = [NSString stringWithUTF8String:s ?: ""];
	int32_t len = (int32_t)n.length;
	Obj* o = alloc(kString, 20 + 2 * (len + 1));
	*(int32_t*)((char*)o + 16) = len;
	[n getCharacters:(unichar*)((char*)o + 20) range:NSMakeRange(0, len)];
	return o;
}
static NSString* nsstr(Obj* s) {
	if (!s) return @"";
	return [NSString stringWithCharacters:(unichar*)((char*)s + 20) length:*(int32_t*)((char*)s + 16)];
}

typedef struct Arr { Obj h; void* bounds; uintptr_t len; } Arr;
static Obj* mkarr(Klass* elem, uintptr_t n) {
	size_t es = elem && elem->valuetype ? elem->size : sizeof(void*);
	Arr* a = (Arr*)alloc(kArray, 32 + n * es);
	a->len = n;
	return (Obj*)a;
}
static void** arr_refs(Obj* a) { return (void**)((char*)a + 32); }

// -- the scene's objects
typedef struct { float x, y, z; } V3;
typedef struct GO GO;
typedef struct Comp { Obj h; GO* go; int enabled; } Comp;
struct GO {
	Obj h;
	const char* name;
	int active, id;
	Comp* comps[6];
	int nc;
	GO* parent;
	GO* kids[12];
	int nkids;
	CGRect rect;   // a UI object's rect in points (top-left origin); a world object's bounds as well
	CALayer* layer;
};
typedef struct { Comp c; Obj* text; } TextC;
typedef struct { Comp c; int on; } ToggleC;
typedef struct { Comp c; float value; } SliderC;
typedef struct { Comp c; Obj* text; int focused; TextC* placeholder; int ended; } InputC;

#define MAXGO 32
static GO* gos[MAXGO];
static int ngo;
static CGSize g_view = { 390, 600 };
static double g_scale = 3;
static TextC *g_score, *g_name;
static InputC* g_input;
static ToggleC* g_toggle;
static int g_score_n;
static UIView* g_unity_view;

static GO* mkgo(const char* name, GO* parent, CGRect r, Klass* tk) {
	GO* g = (GO*)alloc(kGameObject, sizeof(GO));
	g->name = name, g->active = 1, g->id = 1000 + ngo * 2, g->rect = r, g->parent = parent;
	Comp* t = (Comp*)alloc(tk, sizeof(Comp));
	t->go = g, t->enabled = 1;
	g->comps[g->nc++] = t;
	if (parent) parent->kids[parent->nkids++] = g;
	gos[ngo++] = g;
	return g;
}
static Comp* addc(GO* g, Klass* k, size_t sz) {
	Comp* c = (Comp*)alloc(k, sz);
	c->go = g, c->enabled = 1;
	g->comps[g->nc++] = c;
	return c;
}

static int is_a(Klass* k, Klass* base) {
	for (; k; k = k->parent)
		if (k == base) return 1;
	return 0;
}
static int active_in_hierarchy(GO* g) {
	for (; g; g = g->parent)
		if (!g->active) return 0;
	return 1;
}

// -- methods
#define SELF_GO(o) (is_a((o)->klass, kGameObject) ? (GO*)(o) : ((Comp*)(o))->go)
static Obj* m_name(Obj* s, void** a) { return mkstr(SELF_GO(s)->name); }
// a game object's id, its components' the id times 10 plus their index
static Obj* m_iid(Obj* s, void** a) {
	if (is_a(s->klass, kGameObject)) return box_i(((GO*)s)->id);
	GO* g = SELF_GO(s);
	int i = 0;
	while (i < g->nc && (Obj*)g->comps[i] != s) i++;
	return box_i(g->id * 10 + i);
}
static Obj* m_gameObject(Obj* s, void** a) { return (Obj*)SELF_GO(s); }
static Obj* m_transform(Obj* s, void** a) { return (Obj*)SELF_GO(s)->comps[0]; }
static Obj* m_activeInH(Obj* s, void** a) { return box_b(active_in_hierarchy((GO*)s)); }
static Obj* m_enabled(Obj* s, void** a) { return box_b(((Comp*)s)->enabled); }
static Obj* m_isActEn(Obj* s, void** a) { return box_b(((Comp*)s)->enabled && active_in_hierarchy(((Comp*)s)->go)); }
static Klass* type_k(Obj* t) { return t ? *(Klass**)((char*)t + 16) : NULL; }
static Obj* find_in(GO* g, Klass* k) {
	for (int i = 0; i < g->nc; i++)
		if (is_a(g->comps[i]->h.klass, k)) return (Obj*)g->comps[i];
	return NULL;
}
static Obj* m_inParent(Obj* s, void** a) {
	Klass* k = type_k(a[0]);
	for (GO* g = SELF_GO(s); g; g = g->parent) {
		Obj* c = find_in(g, k);
		if (c) return c;
	}
	return NULL;
}
static Obj* inchildren(GO* g, Klass* k) {
	Obj* c = find_in(g, k);
	if (c) return c;
	for (int i = 0; i < g->nkids; i++)
		if ((c = inchildren(g->kids[i], k))) return c;
	return NULL;
}
static Obj* m_inChildren(Obj* s, void** a) { return inchildren(SELF_GO(s), type_k(a[0])); }
static Obj* m_getComponents(Obj* s, void** a) {
	GO* g = (GO*)s;
	Klass* k = type_k(a[0]);
	int n = 0;
	for (int i = 0; i < g->nc; i++) n += is_a(g->comps[i]->h.klass, k);
	Obj* arr = mkarr(kComponent, n);
	for (int i = 0, j = 0; i < g->nc; i++)
		if (is_a(g->comps[i]->h.klass, k)) arr_refs(arr)[j++] = g->comps[i];
	return arr;
}
static Obj* m_find(Obj* s, void** a) {
	Klass* k = type_k(a[0]);
	Obj* tmp[64];
	int n = 0;
	for (int i = 0; i < ngo; i++) {
		if (!active_in_hierarchy(gos[i])) continue;
		if (is_a(kGameObject, k)) tmp[n++] = (Obj*)gos[i];
		for (int j = 0; j < gos[i]->nc && n < 64; j++)
			if (is_a(gos[i]->comps[j]->h.klass, k)) tmp[n++] = (Obj*)gos[i]->comps[j];
	}
	Obj* arr = mkarr(kObject, n);
	memcpy(arr_refs(arr), tmp, n * sizeof(Obj*));
	return arr;
}
static Obj* m_childCount(Obj* s, void** a) { return box_i(((Comp*)s)->go->nkids); }
static Obj* m_getChild(Obj* s, void** a) {
	GO* g = ((Comp*)s)->go;
	int i = *(int32_t*)a[0];
	return i >= 0 && i < g->nkids ? (Obj*)g->kids[i]->comps[0] : NULL;
}
// overlay canvas: world corners are screen pixels, y up
static Obj* m_worldCorners(Obj* s, void** a) {
	CGRect r = ((Comp*)s)->go->rect;
	V3* c = (V3*)((char*)a[0] + 32);
	float x0 = r.origin.x * g_scale, x1 = CGRectGetMaxX(r) * g_scale;
	float yb = (g_view.height - CGRectGetMaxY(r)) * g_scale, yt = (g_view.height - r.origin.y) * g_scale;
	c[0] = (V3){ x0, yb, 0 }, c[1] = (V3){ x0, yt, 0 }, c[2] = (V3){ x1, yt, 0 }, c[3] = (V3){ x1, yb, 0 };
	return NULL;
}
static Obj* m_rootCanvas(Obj* s, void** a) { return s; }
static Obj* m_renderMode(Obj* s, void** a) { return box_i(0); }
static Obj* m_null(Obj* s, void** a) { return NULL; }
static Obj* g_cam;
static Obj* m_main(Obj* s, void** a) { return g_cam; }
// the camera: world units are screen pixels, z 10 in front
static Obj* m_w2s(Obj* s, void** a) {
	V3 p = *(V3*)a[0];
	V3 r = { p.x, p.y, 10 - p.z };
	return box(kVector3, &r, 12);
}
static Obj* m_sw(Obj* s, void** a) { return box_i((int32_t)(g_view.width * g_scale)); }
static Obj* m_sh(Obj* s, void** a) { return box_i((int32_t)(g_view.height * g_scale)); }
static Obj* m_visible(Obj* s, void** a) { return box_b(1); }
static Obj* m_bounds(Obj* s, void** a) {
	CGRect r = ((Comp*)s)->go->rect;
	float b[6] = { CGRectGetMidX(r) * g_scale, (g_view.height - CGRectGetMidY(r)) * g_scale, 0, r.size.width / 2 * g_scale,
		r.size.height / 2 * g_scale, 0.5 };
	return box(kBounds, b, 24);
}
static Obj* m_interactable(Obj* s, void** a) { return box_b(1); }
static Obj* m_text(Obj* s, void** a) { return ((TextC*)s)->text; }
static Obj* m_isOn(Obj* s, void** a) { return box_b(((ToggleC*)s)->on); }
static Obj* m_value(Obj* s, void** a) { return box_f(((SliderC*)s)->value); }
static Obj* m_min(Obj* s, void** a) { return box_f(0); }
static Obj* m_max(Obj* s, void** a) { return box_f(1); }
static void refresh(void);
static Obj* m_inText(Obj* s, void** a) { return ((InputC*)s)->text; }
static Obj* m_setInText(Obj* s, void** a) {
	((InputC*)s)->text = a[0];
	x86unity_log("set_text", nsstr(a[0]).UTF8String);   // onValueChanged
	dispatch_async(dispatch_get_main_queue(), ^{ refresh(); });
	return NULL;
}
static Obj* m_focused(Obj* s, void** a) { return box_b(((InputC*)s)->focused); }
static Obj* m_placeholder(Obj* s, void** a) { return (Obj*)((InputC*)s)->placeholder; }
typedef struct { Obj h; InputC* field; } Ev;
static Obj* m_onEndEdit(Obj* s, void** a) {
	Ev* e = (Ev*)alloc(kEvent, sizeof(Ev));
	e->field = (InputC*)s;
	return (Obj*)e;
}
static Obj* m_invoke(Obj* s, void** a) {
	((Ev*)s)->field->ended++;
	x86unity_log("end_edit", nsstr(a[0]).UTF8String);
	dispatch_async(dispatch_get_main_queue(), ^{ refresh(); });
	return NULL;
}
static Obj* m_sceneCount(Obj* s, void** a) { return box_i(1); }
static Obj* m_sceneAt(Obj* s, void** a) { int32_t h = 77; return box(kScene, &h, 4); }
// Scene.GetRootGameObjects: `this` is the value's address (Mono's convention); the handle must be the scene's
static Obj* m_roots(Obj* s, void** a) {
	if (*(int32_t*)s != 77) return mkarr(kGameObject, 0);
	int n = 0;
	for (int i = 0; i < ngo; i++) n += !gos[i]->parent;
	Obj* arr = mkarr(kGameObject, n);
	for (int i = 0, j = 0; i < ngo; i++)
		if (!gos[i]->parent) arr_refs(arr)[j++] = gos[i];
	return arr;
}

static void build_types(void) {
	kObject = defk("UnityEngine", "Object", NULL);
	kString = defk("System", "String", NULL);
	kInt = defk("System", "Int32", NULL), kInt->valuetype = 1, kInt->size = 4;
	kBool = defk("System", "Boolean", NULL), kBool->valuetype = 1, kBool->size = 1;
	kFloat = defk("System", "Single", NULL), kFloat->valuetype = 1, kFloat->size = 4;
	kType = defk("System", "Type", NULL);
	kArray = defk("System", "Array", NULL);
	kVector3 = defk("UnityEngine", "Vector3", NULL), kVector3->valuetype = 1, kVector3->size = 12;
	kBounds = defk("UnityEngine", "Bounds", NULL), kBounds->valuetype = 1, kBounds->size = 24;
	kComponent = defk("UnityEngine", "Component", kObject);
	kBehaviour = defk("UnityEngine", "Behaviour", kComponent);
	kGameObject = defk("UnityEngine", "GameObject", kObject);
	kTransform = defk("UnityEngine", "Transform", kComponent);
	kRectTransform = defk("UnityEngine", "RectTransform", kTransform);
	kCanvas = defk("UnityEngine", "Canvas", kBehaviour);
	kCamera = defk("UnityEngine", "Camera", kBehaviour);
	kScreen = defk("UnityEngine", "Screen", NULL);
	kRenderer = defk("UnityEngine", "Renderer", kComponent);
	kSelectable = defk("UnityEngine.UI", "Selectable", kBehaviour);
	kButton = defk("UnityEngine.UI", "Button", kSelectable);
	kToggle = defk("UnityEngine.UI", "Toggle", kSelectable);
	kSlider = defk("UnityEngine.UI", "Slider", kSelectable);
	kInputField = defk("UnityEngine.UI", "InputField", kSelectable);
	kGraphic = defk("UnityEngine.UI", "Graphic", kBehaviour);
	kText = defk("UnityEngine.UI", "Text", kGraphic);
	kEvent = defk("UnityEngine.Events", "UnityEvent`1", NULL);
	kSceneManager = defk("UnityEngine.SceneManagement", "SceneManager", NULL);
	kScene = defk("UnityEngine.SceneManagement", "Scene", NULL), kScene->valuetype = 1, kScene->size = 4;

	defm(kObject, "get_name", 0, NULL, m_name, 0);
	defm(kObject, "GetInstanceID", 0, NULL, m_iid, 0);
	if (!g_stripped) {
		defm(kObject, "FindObjectsByType", 2, "System.Type", m_find, 1);
		defm(kObject, "FindObjectsOfType", 1, "System.Type", m_find, 1);
	}
	defm(kComponent, "get_gameObject", 0, NULL, m_gameObject, 0);
	defm(kComponent, "get_transform", 0, NULL, m_transform, 0);
	defm(kComponent, "GetComponentInParent", 1, "System.Type", m_inParent, 0);
	defm(kComponent, "GetComponentInChildren", 1, "System.Type", m_inChildren, 0);
	defm(kComponent, "GetComponent", 1, "System.String", m_null, 0);   // the overload the reader must not take
	defm(kBehaviour, "get_enabled", 0, NULL, m_enabled, 0);
	defm(kBehaviour, "get_isActiveAndEnabled", 0, NULL, m_isActEn, 0);
	defm(kGameObject, "get_activeInHierarchy", 0, NULL, m_activeInH, 0);
	defm(kGameObject, "get_transform", 0, NULL, m_transform, 0);
	defm(kGameObject, "GetComponents", 1, "System.Type", m_getComponents, 0);
	defm(kTransform, "get_childCount", 0, NULL, m_childCount, 0);
	defm(kTransform, "GetChild", 1, NULL, m_getChild, 0);
	defm(kRectTransform, "GetWorldCorners", 1, NULL, m_worldCorners, 0);
	defm(kCanvas, "get_rootCanvas", 0, NULL, m_rootCanvas, 0);
	defm(kCanvas, "get_renderMode", 0, NULL, m_renderMode, 0);
	defm(kCanvas, "get_worldCamera", 0, NULL, m_null, 0);
	defm(kCamera, "get_main", 0, NULL, m_main, 1);
	defm(kCamera, "WorldToScreenPoint", 1, "UnityEngine.Vector3", m_w2s, 0);
	defm(kScreen, "get_width", 0, NULL, m_sw, 1);
	defm(kScreen, "get_height", 0, NULL, m_sh, 1);
	defm(kRenderer, "get_enabled", 0, NULL, m_enabled, 0);
	defm(kRenderer, "get_isVisible", 0, NULL, m_visible, 0);
	defm(kRenderer, "get_bounds", 0, NULL, m_bounds, 0);
	defm(kSelectable, "IsInteractable", 0, NULL, m_interactable, 0);
	defm(kText, "get_text", 0, NULL, m_text, 0);
	defm(kToggle, "get_isOn", 0, NULL, m_isOn, 0);
	defm(kSlider, "get_value", 0, NULL, m_value, 0);
	defm(kSlider, "get_minValue", 0, NULL, m_min, 0);
	defm(kSlider, "get_maxValue", 0, NULL, m_max, 0);
	defm(kInputField, "get_text", 0, NULL, m_inText, 0);
	defm(kInputField, "set_text", 1, NULL, m_setInText, 0);
	defm(kInputField, "get_isFocused", 0, NULL, m_focused, 0);
	defm(kInputField, "get_placeholder", 0, NULL, m_placeholder, 0);
	defm(kInputField, "get_onEndEdit", 0, NULL, m_onEndEdit, 0);
	defm(kEvent, "Invoke", 1, NULL, m_invoke, 0);
	defm(kSceneManager, "get_sceneCount", 0, NULL, m_sceneCount, 1);
	defm(kSceneManager, "GetSceneAt", 1, NULL, m_sceneAt, 1);
	defm(kScene, "GetRootGameObjects", 0, NULL, m_roots, 0);
}

static TextC* text_go(const char* name, GO* parent, CGRect r, const char* text) {
	GO* g = mkgo(name, parent, r, kRectTransform);
	TextC* t = (TextC*)addc(g, kText, sizeof(TextC));
	t->text = mkstr(text);
	return t;
}

static void build_scene(void) {
	GO* canvas = mkgo("Canvas", NULL, CGRectMake(0, 0, g_view.width, g_view.height), kRectTransform);
	addc(canvas, kCanvas, sizeof(Comp));
	GO* play = mkgo("PlayButton", canvas, CGRectMake(40, 60, 140, 50), kRectTransform);
	addc(play, kButton, sizeof(Comp));
	text_go("Text", play, CGRectMake(50, 70, 120, 30), "Play");
	GO* sound = mkgo("SoundToggle", canvas, CGRectMake(210, 60, 140, 50), kRectTransform);
	g_toggle = (ToggleC*)addc(sound, kToggle, sizeof(ToggleC));
	g_toggle->on = 1;
	text_go("Label", sound, CGRectMake(240, 70, 100, 30), "Sound");
	GO* vol = mkgo("Volume", canvas, CGRectMake(40, 140, 310, 30), kRectTransform);
	((SliderC*)addc(vol, kSlider, sizeof(SliderC)))->value = 0.25f;
	GO* name = mkgo("NameField", canvas, CGRectMake(40, 200, 310, 44), kRectTransform);
	g_input = (InputC*)addc(name, kInputField, sizeof(InputC));
	g_input->text = mkstr("");
	g_input->placeholder = text_go("Placeholder", name, CGRectMake(48, 206, 290, 32), "Your name");
	g_score = text_go("Score", canvas, CGRectMake(40, 270, 310, 30), "Score: 0");
	g_name = text_go("NameEcho", canvas, CGRectMake(40, 310, 310, 30), "Name:  ended 0");
	GO* world = mkgo("World", NULL, CGRectZero, kTransform);
	GO* player = mkgo("Player", world, CGRectMake(150, 420, 90, 90), kTransform);
	addc(player, kRenderer, sizeof(Comp));
	GO* ghost = mkgo("Ghost", world, CGRectMake(40, 420, 60, 60), kTransform);
	addc(ghost, kRenderer, sizeof(Comp));
	ghost->active = 0;
	GO* cam = mkgo("Main Camera", NULL, CGRectZero, kTransform);
	g_cam = (Obj*)addc(cam, kCamera, sizeof(Comp));
}

// -- the IL2CPP API
typedef struct { int dummy; } Domain, Assembly, Image;
static Domain g_domain;
static Assembly g_asm;
static Image g_img;
static Assembly* g_asms[1] = { &g_asm };

void* il2cpp_domain_get(void) { return &g_domain; }
void** il2cpp_domain_get_assemblies(void* d, size_t* n) { *n = 1; return (void**)g_asms; }
void* il2cpp_assembly_get_image(void* a) { return &g_img; }
Klass* il2cpp_class_from_name(void* img, const char* ns, const char* name) {
	for (int i = 0; i < nk; i++)
		if (!strcmp(K[i].ns, ns) && !strcmp(K[i].name, name)) return &K[i];
	return NULL;
}
Method* il2cpp_class_get_methods(Klass* k, void** it) {
	intptr_t i = (intptr_t)*it;
	if (i >= k->nm) return NULL;
	*it = (void*)(i + 1);
	return &k->methods[i];
}
Klass* il2cpp_class_get_parent(Klass* k) { return k->parent; }
const IType* il2cpp_class_get_type(Klass* k) { return &k->type; }
int il2cpp_class_is_assignable_from(Klass* k, Klass* o) { return is_a(o, k); }
const char* il2cpp_class_get_name(Klass* k) { return k->name; }
void* il2cpp_class_get_field_from_name(Klass* k, const char* n) { return NULL; }
void il2cpp_field_get_value(Obj* o, void* f, void* v) {}
const char* il2cpp_method_get_name(Method* m) { return m->name; }
uint32_t il2cpp_method_get_param_count(Method* m) { return m->argc; }
const IType* il2cpp_method_get_param(Method* m, uint32_t i) {
	if (!m->p0 || i) return &kObject->type;
	const char* dot = strrchr(m->p0, '.');
	char ns[64];
	snprintf(ns, sizeof(ns), "%.*s", (int)(dot - m->p0), m->p0);
	Klass* k = il2cpp_class_from_name(NULL, ns, dot + 1);
	if (!k) k = defk(strdup(ns), strdup(dot + 1), NULL);
	return &k->type;
}
int il2cpp_method_is_generic(Method* m) { return 0; }
char* il2cpp_type_get_name(const IType* t) {
	char* s = malloc(128);
	snprintf(s, 128, "%s.%s", t->k->ns, t->k->name);
	return s;
}
void il2cpp_free(void* p) { free(p); }
Obj* il2cpp_type_get_object(const IType* t) {
	Klass* k = t->k;
	return box(kType, &k, sizeof(k));
}
Klass* il2cpp_object_get_class(Obj* o) { return o->klass; }
Method* il2cpp_object_get_virtual_method(Obj* o, Method* m) { return m; }
void* il2cpp_object_unbox(Obj* o) { return (char*)o + 16; }
Obj* il2cpp_runtime_invoke(Method* m, void* self, void** args, Obj** exc) {
	*exc = NULL;
	if (!m->is_static && !self) {
		*exc = mkstr("NullReferenceException");
		return NULL;
	}
	return m->fn(self, args);
}
Obj* il2cpp_string_new(const char* s) { return mkstr(s); }
uint16_t* il2cpp_string_chars(Obj* s) { return (uint16_t*)((char*)s + 20); }
int32_t il2cpp_string_length(Obj* s) { return *(int32_t*)((char*)s + 16); }
uint32_t il2cpp_array_length(Obj* a) { return (uint32_t)((Arr*)a)->len; }
Obj* il2cpp_array_new(Klass* k, uintptr_t n) { return mkarr(k, n); }

// -- the view
@interface UnityView : UIView
@end

static CALayer* layer_for(GO* g, UIColor* c) {
	CATextLayer* l = [CATextLayer layer];
	l.frame = g->rect;
	l.backgroundColor = c.CGColor;
	l.fontSize = 16;
	l.foregroundColor = UIColor.whiteColor.CGColor;
	l.contentsScale = g_scale;
	[g_unity_view.layer addSublayer:l];
	return l;
}

static void refresh(void) {
	char b[160];
	snprintf(b, sizeof(b), "Score: %d", g_score_n);
	g_score->text = mkstr(b);
	snprintf(b, sizeof(b), "Name: %s ended %d", nsstr(g_input->text).UTF8String, g_input->ended);
	g_name->text = mkstr(b);
	for (int i = 0; i < ngo; i++) {
		CATextLayer* l = (CATextLayer*)gos[i]->layer;
		if (!l) continue;
		Obj* t = find_in(gos[i], kText);
		if (t) l.string = nsstr(((TextC*)t)->text);
	}
}

@implementation UnityView
- (instancetype)initWithFrame:(CGRect)f {
	self = [super initWithFrame:f];
	g_unity_view = self;
	self.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
	return self;
}
- (void)layoutSubviews {
	[super layoutSubviews];
	if (ngo) return;
	g_view = self.bounds.size;
	g_scale = self.window.screen.scale ?: 3;
	g_stripped = getenv("X86UNITY_STRIPPED") != NULL;
	build_types();
	build_scene();
	for (int i = 0; i < ngo; i++) {
		GO* g = gos[i];
		if (!g->active || CGRectIsEmpty(g->rect) || !strcmp(g->name, "Canvas")) continue;
		UIColor* c = find_in(g, kButton) ? UIColor.systemBlueColor : find_in(g, kRenderer) ? UIColor.systemRedColor
			: find_in(g, kText) ? UIColor.clearColor : UIColor.darkGrayColor;
		g->layer = layer_for(g, c);
	}
	refresh();
	x86unity_log("scene", g_stripped ? "stripped" : "full");
}
- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
	CGPoint p = [touches.anyObject locationInView:self];
	// front-most first: the last made
	for (int i = ngo - 1; i >= 0; i--) {
		GO* g = gos[i];
		if (!active_in_hierarchy(g) || !CGRectContainsPoint(g->rect, p) || find_in(g, kText) || !strcmp(g->name, "Canvas")) continue;
		g_input->focused = find_in(g, kInputField) != NULL;
		if (find_in(g, kButton)) g_score_n++;
		if (find_in(g, kToggle)) g_toggle->on = !g_toggle->on;
		x86unity_log("touch", g->name);
		refresh();
		return;
	}
	g_input->focused = 0;
}
@end
