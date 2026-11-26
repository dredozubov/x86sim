// x86Sim: simax's Unity reader (hooked from simax_engines.m / simax.m; protocol: docs/protocols/SIMAX.md, "Engines").
//
// A Unity iOS player is an IL2CPP build: UnityFramework exports IL2CPP's reflection API (il2cpp_*), and Unity's player
// loop runs on the main thread, where simax answers requests. So, in a process with UnityFramework loaded and a
// UnityView that gave no accessibility elements of its own (no accessibility plugin, no AccessibilityHierarchy):
//   - uGUI Button / Toggle / Slider / InputField / Text and TextMeshPro TMP_Text / TMP_InputField: label, value,
//     enabled, focused; their RectTransform's world corners through their canvas (screen space overlay: already screen
//     pixels; camera / world space: the canvas's camera, else Camera.main) to Unity's screen pixels, then to the view's
//     points (Unity's y goes up). Roles button, switch, adjustable, textfield, text (simax's usual names).
//   - UI Toolkit: each UIDocument's visual tree: Button, Toggle, Slider / SliderInt, TextField, Label, from the panel's
//     coordinates to the screen's through RuntimePanelUtils.ScreenToPanel.
//   - game objects: active ones with a name and a renderer (visible to a camera) or a collider become `node`
//     elements, their bounds' corners projected with Camera.main.
// Objects are found with Object.FindObjectsByType / FindObjectsOfType; when code stripping removed both, the active
// scenes' root objects are walked through their transforms (SceneManager.GetSceneAt, Scene.GetRootGameObjects).
// Keys: "unity:<instance id>" (Object.GetInstanceID: the same object for its life, wherever it moves), UI Toolkit
// "uitk:<document id>/<child indexes>".
//
// type: the focused InputField / TMP_InputField (isFocused) gets its text through the component (the text setter
// fires onValueChanged), then onEndEdit; the on-screen keyboard's TouchScreenKeyboard, when the field has one, gets
// the same text (the field reads it back every frame). A focused UI Toolkit TextField gets its value.
#include <TargetConditionals.h>
#if TARGET_OS_WATCH
// (as simax.m: watchOS's headers mark UIKit unavailable, UIKitCore runs every watch app)
#include <AvailabilityInternal.h>
#undef __API_UNAVAILABLE_PLATFORM_watchos
#define __API_UNAVAILABLE_PLATFORM_watchos watchos,introduced=2.0
#endif
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <string.h>

void simax_log(const char* fmt, ...);

typedef void Obj;      // Il2CppObject
typedef void Klass;    // Il2CppClass
typedef void UMethod;   // MethodInfo
typedef void IType;    // Il2CppType

static struct {
	BOOL tried, ok;
	void* (*domain_get)(void);
	void** (*domain_get_assemblies)(void*, size_t*);
	void* (*assembly_get_image)(void*);
	Klass* (*class_from_name)(void*, const char*, const char*);
	UMethod* (*class_get_methods)(Klass*, void**);
	Klass* (*class_get_parent)(Klass*);
	const IType* (*class_get_type)(Klass*);
	BOOL (*class_is_assignable_from)(Klass*, Klass*);
	const char* (*class_get_name)(Klass*);
	void* (*class_get_field_from_name)(Klass*, const char*);
	const char* (*method_get_name)(UMethod*);
	uint32_t (*method_get_param_count)(UMethod*);
	const IType* (*method_get_param)(UMethod*, uint32_t);
	BOOL (*method_is_generic)(UMethod*);
	uint32_t (*method_get_flags)(UMethod*, uint32_t*);
	char* (*type_get_name)(const IType*);
	Obj* (*type_get_object)(const IType*);
	Klass* (*object_get_class)(Obj*);
	UMethod* (*object_get_virtual_method)(Obj*, UMethod*);
	void* (*object_unbox)(Obj*);
	Obj* (*runtime_invoke)(UMethod*, void*, void**, Obj**);
	Obj* (*string_new)(const char*);
	uint16_t* (*string_chars)(Obj*);
	int32_t (*string_length)(Obj*);
	uint32_t (*array_length)(Obj*);
	Obj* (*array_new)(Klass*, uintptr_t);
	void (*field_get_value)(Obj*, void*, void*);
	void (*free_fn)(void*);
	void* (*resolve_icall)(const char*);
} U;

static const size_t kArrayData = 32;   // Il2CppArray: klass, monitor, bounds, max_length, then the elements (64-bit)
static NSMutableDictionary* g_classes;  // "ns.name" -> class (NSValue), or NSNull: not in this build
static NSMutableDictionary* g_methods;  // "class ptr.name/argc/param0" -> method or NSNull

static BOOL u_init(void) {
	if (U.tried) return U.ok;
	void* h = NULL;
	for (uint32_t i = 0, n = _dyld_image_count(); i < n && !h; i++) {
		const char* p = _dyld_get_image_name(i);
		if (p && strstr(p, "/UnityFramework.framework/UnityFramework")) h = dlopen(p, RTLD_NOLOAD | RTLD_LAZY);
	}
	if (!h) return NO;   // not yet: UnityFramework may load later (an app embedding Unity loads it on demand)
	U.tried = YES;
#define S(f) *(void**)&U.f = dlsym(h, "il2cpp_" #f)
	S(domain_get); S(domain_get_assemblies); S(assembly_get_image); S(class_from_name); S(class_get_methods);
	S(class_get_parent); S(class_get_type); S(class_is_assignable_from); S(class_get_name); S(class_get_field_from_name);
	S(method_get_name); S(method_get_param_count); S(method_get_param); S(method_is_generic); S(method_get_flags);
	S(type_get_name); S(type_get_object); S(object_get_class); S(object_get_virtual_method); S(object_unbox);
	S(runtime_invoke); S(string_new); S(string_chars); S(string_length); S(array_length); S(array_new); S(field_get_value);
	*(void**)&U.free_fn = dlsym(h, "il2cpp_free");
	*(void**)&U.resolve_icall = dlsym(h, "il2cpp_resolve_icall");
#undef S
	U.ok = U.domain_get && U.domain_get_assemblies && U.assembly_get_image && U.class_from_name && U.class_get_methods &&
		U.class_get_parent && U.class_get_type && U.class_is_assignable_from && U.method_get_name && U.method_get_param_count &&
		U.method_get_param && U.type_get_name && U.type_get_object && U.object_get_class && U.object_unbox && U.runtime_invoke &&
		U.string_new && U.string_chars && U.string_length && U.array_length && U.array_new;
	g_classes = [NSMutableDictionary dictionary];
	g_methods = [NSMutableDictionary dictionary];
	simax_log("unity: il2cpp API %s", U.ok ? "found" : "incomplete (no reader)");
	return U.ok;
}

// a class by namespace and name, in whichever assembly has it (UnityEngine.UI, Unity.TextMeshPro, UnityEngine.*Module)
static Klass* u_class(const char* ns, const char* name) {
	NSString* k = [NSString stringWithFormat:@"%s.%s", ns, name];
	id c = g_classes[k];
	if (c) return c == [NSNull null] ? NULL : [c pointerValue];
	Klass* found = NULL;
	size_t n = 0;
	void** as = U.domain_get_assemblies(U.domain_get(), &n);
	for (size_t i = 0; i < n && !found; i++) found = U.class_from_name(U.assembly_get_image(as[i]), ns, name);
	g_classes[k] = found ? [NSValue valueWithPointer:found] : [NSNull null];
	return found;
}

// a method of a class or its parents by name and argument count; p0: the first parameter's type name, when overloads
// share both (GetComponent(Type) / GetComponent(string)). Generic method definitions are never taken.
static UMethod* u_method(Klass* k, const char* name, int argc, const char* p0) {
	if (!k) return NULL;
	NSString* key = [NSString stringWithFormat:@"%p.%s/%d/%s", k, name, argc, p0 ?: ""];
	id c = g_methods[key];
	if (c) return c == [NSNull null] ? NULL : [c pointerValue];
	UMethod* found = NULL;
	for (Klass* kk = k; kk && !found; kk = U.class_get_parent(kk)) {
		void* it = NULL;
		for (UMethod* m; !found && (m = U.class_get_methods(kk, &it));) {
			if (strcmp(U.method_get_name(m), name) || (int)U.method_get_param_count(m) != argc) continue;
			if (U.method_is_generic && U.method_is_generic(m)) continue;
			if (p0 && argc > 0) {
				char* tn = U.type_get_name(U.method_get_param(m, 0));
				BOOL same = tn && !strcmp(tn, p0);
				if (tn && U.free_fn) U.free_fn(tn);
				if (!same) continue;
			}
			found = m;
		}
	}
	g_methods[key] = found ? [NSValue valueWithPointer:found] : [NSNull null];
	return found;
}

static BOOL u_is(Obj* o, Klass* k) { return o && k && U.class_is_assignable_from(k, U.object_get_class(o)); }

// Calls a method; an instance method is resolved on the object's class (overrides). NULL and *ok NO when the method is
// missing (stripped) or threw. Value types come back boxed.
static Obj* u_invoke(UMethod* m, Obj* self, void** args, BOOL* ok) {
	if (ok) *ok = NO;
	if (!m) return NULL;
	if (self && U.object_get_virtual_method) m = U.object_get_virtual_method(self, m) ?: m;
	Obj* exc = NULL;
	Obj* r = U.runtime_invoke(m, self, args, &exc);
	if (exc) return NULL;
	if (ok) *ok = YES;
	return r;
}

static Obj* u_call(Obj* self, const char* name, int argc, const char* p0, void** args, BOOL* ok) {
	if (ok) *ok = NO;
	if (!self) return NULL;
	return u_invoke(u_method(U.object_get_class(self), name, argc, p0), self, args, ok);
}

static Obj* u_get(Obj* self, const char* prop) {
	char n[96];
	snprintf(n, sizeof(n), "get_%s", prop);
	return u_call(self, n, 0, NULL, NULL, NULL);
}

static Obj* u_static(Klass* k, const char* name, int argc, const char* p0, void** args) {
	return u_invoke(u_method(k, name, argc, p0), NULL, args, NULL);
}

static NSString* u_str(Obj* s) {
	if (!s) return nil;
	int32_t n = U.string_length(s);
	if (n <= 0) return nil;
	return [NSString stringWithCharacters:U.string_chars(s) length:MIN(n, 2000)];
}

static BOOL u_b(Obj* boxed, BOOL dflt) { return boxed ? *(uint8_t*)U.object_unbox(boxed) != 0 : dflt; }
static int32_t u_i32(Obj* boxed, int32_t dflt) { return boxed ? *(int32_t*)U.object_unbox(boxed) : dflt; }
static float u_f32(Obj* boxed, float dflt) { return boxed ? *(float*)U.object_unbox(boxed) : dflt; }

static Obj* u_typeof(Klass* k) { return k ? U.type_get_object(U.class_get_type(k)) : NULL; }

static NSString* hexp(void* p) { return [NSString stringWithFormat:@"%lx", (unsigned long)(uintptr_t)p]; }

// ---------------------------------------------------------------------------------------------------------------------
// Finding objects

// every active object of a class: FindObjectsByType(Type, FindObjectsSortMode.None) (2023.1+), else FindObjectsOfType(Type)
static NSArray* u_find(Klass* k, BOOL* stripped) {
	Klass* object = u_class("UnityEngine", "Object");
	Obj* t = u_typeof(k);
	if (!object || !t) return @[];
	int32_t none = 0;
	void* a2[] = { t, &none };
	BOOL ok = NO;
	Obj* arr = NULL;
	UMethod* m = u_method(object, "FindObjectsByType", 2, "System.Type");
	if (m) arr = u_invoke(m, NULL, a2, &ok);
	if (!ok) {
		void* a1[] = { t };
		m = u_method(object, "FindObjectsOfType", 1, "System.Type");
		if (m) arr = u_invoke(m, NULL, a1, &ok);
	}
	if (!ok) {
		// the managed wrappers stripped (a game that never calls them): the engine still registers the native call
		// behind FindObjectsByType, which IL2CPP resolves by name; a static icall takes its arguments as they are
		typedef Obj* (*FindFn)(Obj* type, int32_t inactive, int32_t sort);
		static FindFn find;
		static BOOL looked;
		if (!looked && U.resolve_icall) {
			looked = YES;
			find = (FindFn)U.resolve_icall("UnityEngine.Object::FindObjectsByType(System.Type,UnityEngine.FindObjectsInactive,UnityEngine.FindObjectsSortMode)");
			simax_log("unity: FindObjectsByType icall %s", find ? "found" : "missing");
		}
		if (find) {
			arr = find(t, 0, 0);
			ok = YES;
			m = (UMethod*)1;
		}
	}
	if (!m) *stripped = YES;
	NSMutableArray* out = [NSMutableArray array];
	if (!arr) return out;
	uint32_t n = U.array_length(arr);
	Obj** e = (Obj**)((char*)arr + kArrayData);
	for (uint32_t i = 0; i < n && i < 2000; i++)
		if (e[i]) [out addObject:[NSValue valueWithPointer:e[i]]];
	return out;
}

// The fallback when the lookups were stripped: the loaded scenes' root objects and everything under their transforms,
// active ones only; their components of the classes asked for.
static void u_walk_go(Obj* go, NSArray* classes, NSMutableArray* out, int depth) {
	if (!go || depth > 64 || out.count > 4000) return;
	if (!u_b(u_get(go, "activeInHierarchy"), YES)) return;
	Klass* component = u_class("UnityEngine", "Component");
	BOOL ok = NO;
	void* a[] = { u_typeof(component) };
	Obj* comps = u_call(go, "GetComponents", 1, "System.Type", a, &ok);
	if (ok && comps) {
		uint32_t n = U.array_length(comps);
		Obj** e = (Obj**)((char*)comps + kArrayData);
		for (uint32_t i = 0; i < n; i++)
			for (NSValue* k in classes)
				if (u_is(e[i], k.pointerValue)) { [out addObject:[NSValue valueWithPointer:e[i]]]; break; }
	}
	Obj* tr = u_get(go, "transform");
	int32_t kids = u_i32(u_get(tr, "childCount"), 0);
	for (int32_t i = 0; i < kids && i < 1000; i++) {
		void* ai[] = { &i };
		Obj* c = u_call(tr, "GetChild", 1, NULL, ai, NULL);
		u_walk_go(u_get(c, "gameObject"), classes, out, depth + 1);
	}
}

static NSArray* u_scene_walk(NSArray* classes) {
	NSMutableArray* out = [NSMutableArray array];
	Klass* sm = u_class("UnityEngine.SceneManagement", "SceneManager");
	Klass* scene = u_class("UnityEngine.SceneManagement", "Scene");
	int32_t count = u_i32(u_static(sm, "get_sceneCount", 0, NULL, NULL), 0);
	UMethod* roots = u_method(scene, "GetRootGameObjects", 0, NULL);
	for (int32_t i = 0; i < count && i < 64 && roots; i++) {
		void* ai[] = { &i };
		Obj* boxed = u_static(sm, "GetSceneAt", 1, NULL, ai);
		if (!boxed) continue;
		int32_t handle = *(int32_t*)U.object_unbox(boxed);
		// a struct's instance method: IL2CPP takes the value's address (Mono's convention) where some versions take
		// the boxed object; the handle (Scene's one field) sits at both offsets, so either reads it
		int64_t self[4] = { handle, 0, handle, 0 };
		Obj* gos = u_invoke(roots, self, NULL, NULL);
		if (!gos) continue;
		uint32_t n = U.array_length(gos);
		Obj** e = (Obj**)((char*)gos + kArrayData);
		for (uint32_t j = 0; j < n; j++) u_walk_go(e[j], classes, out, 0);
	}
	return out;
}

// the active objects of these classes: looked up, or when the lookups were stripped, from the scenes' walk
static NSArray* u_objects(NSArray* classes) {
	NSMutableArray* out = [NSMutableArray array];
	BOOL stripped = NO;
	for (NSValue* k in classes) [out addObjectsFromArray:u_find(k.pointerValue, &stripped)];
	if (stripped && !out.count) {
		[out addObjectsFromArray:u_scene_walk(classes)];
		simax_log("unity: object lookups stripped; the scene walk found %lu", (unsigned long)out.count);
	}
	return out;
}

// ---------------------------------------------------------------------------------------------------------------------
// Geometry: Unity's screen pixels (origin bottom left) -> the UnityView's points

typedef struct { float x, y, z; } UV3;
typedef struct {
	CGSize view;      // the UnityView's bounds
	float sw, sh;     // Screen.width / height
	Obj* cam;         // Camera.main
} Geo;

static CGRect px_to_view(Geo* g, float x0, float y0, float x1, float y1) {
	double kx = g->view.width / g->sw, ky = g->view.height / g->sh;
	return CGRectMake(x0 * kx, (g->sh - y1) * ky, (x1 - x0) * kx, (y1 - y0) * ky);
}

static BOOL world_to_screen(Obj* cam, UV3 p, UV3* out) {
	if (!cam) return NO;
	void* a[] = { &p };
	BOOL ok = NO;
	Obj* r = u_call(cam, "WorldToScreenPoint", 1, "UnityEngine.Vector3", a, &ok);
	if (!ok || !r) return NO;
	*out = *(UV3*)U.object_unbox(r);
	return YES;
}

// a RectTransform's rect on the screen, through its canvas
static CGRect ui_rect(Geo* g, Obj* comp) {
	Obj* rt = u_get(comp, "transform");
	Klass* v3 = u_class("UnityEngine", "Vector3");
	Obj* corners = v3 ? U.array_new(v3, 4) : NULL;
	BOOL ok = NO;
	void* a[] = { corners };
	if (corners) u_call(rt, "GetWorldCorners", 1, NULL, a, &ok);
	if (!ok) return CGRectNull;
	UV3* c = (UV3*)((char*)corners + kArrayData);
	// the root canvas decides: overlay (0) draws in screen pixels; camera (1) and world (2) go through a camera
	Klass* canvas = u_class("UnityEngine", "Canvas");
	void* ac[] = { u_typeof(canvas) };
	Obj* cv = canvas ? u_call(comp, "GetComponentInParent", 1, "System.Type", ac, NULL) : NULL;
	Obj* root = cv ? (u_get(cv, "rootCanvas") ?: cv) : NULL;
	int32_t mode = root ? u_i32(u_get(root, "renderMode"), 0) : 0;
	Obj* cam = mode ? (u_get(root, "worldCamera") ?: (mode == 2 ? g->cam : NULL)) : NULL;
	float x0 = INFINITY, y0 = INFINITY, x1 = -INFINITY, y1 = -INFINITY;
	for (int i = 0; i < 4; i++) {
		UV3 s = c[i];
		if (cam && !world_to_screen(cam, c[i], &s)) return CGRectNull;
		if (cam && s.z < 0) return CGRectNull;
		x0 = MIN(x0, s.x); y0 = MIN(y0, s.y); x1 = MAX(x1, s.x); y1 = MAX(y1, s.y);
	}
	return px_to_view(g, x0, y0, x1, y1);
}

// ---------------------------------------------------------------------------------------------------------------------
// Elements

static NSString* go_name(Obj* comp) { return u_str(u_get(u_get(comp, "gameObject"), "name")); }

static NSString* text_of(Obj* o) {
	Klass* text = u_class("UnityEngine.UI", "Text");
	Klass* tmp = u_class("TMPro", "TMP_Text");
	if (u_is(o, text) || u_is(o, tmp)) return u_str(u_get(o, "text"));
	return nil;
}

// the text a control shows: its first Text / TMP_Text child's
static NSString* child_text(Obj* comp) {
	const char* names[][2] = { { "UnityEngine.UI", "Text" }, { "TMPro", "TMP_Text" } };
	for (int i = 0; i < 2; i++) {
		Klass* k = u_class(names[i][0], names[i][1]);
		if (!k) continue;
		void* a[] = { u_typeof(k) };
		Obj* t = u_call(comp, "GetComponentInChildren", 1, "System.Type", a, NULL);
		NSString* s = text_of(t);
		if (s) return s;
	}
	return nil;
}

static NSString* fmtf(float v) { return v == (long)v ? [NSString stringWithFormat:@"%ld", (long)v] : [NSString stringWithFormat:@"%g", v]; }

static void add(NSMutableArray* out, Obj* comp, NSString* role, NSString* label, NSString* value, CGRect r, NSString* key, NSString* cls) {
	if (CGRectIsNull(r) || r.size.width < 0.5 || r.size.height < 0.5) return;
	NSMutableDictionary* d = [NSMutableDictionary dictionary];
	d[@"role"] = role;
	if (label) d[@"label"] = label.length > 400 ? [label substringToIndex:400] : label;
	if (value) d[@"value"] = value.length > 400 ? [value substringToIndex:400] : value;
	d[@"rect"] = [NSValue valueWithCGRect:r];
	d[@"oid"] = hexp(comp);
	d[@"class"] = cls;
	d[@"key"] = key;
	d[@"engine"] = @"unity";
	[out addObject:d];
}

static NSString* inst_key(Obj* comp) {
	BOOL ok = NO;
	Obj* id_ = u_call(comp, "GetInstanceID", 0, NULL, NULL, &ok);
	return ok ? [NSString stringWithFormat:@"unity:%d", u_i32(id_, 0)] : [@"unity:" stringByAppendingString:hexp(comp)];
}

// uGUI / TextMeshPro
static void ugui(Geo* g, NSArray* comps, NSMutableArray* out) {
	Klass *button = u_class("UnityEngine.UI", "Button"), *toggle = u_class("UnityEngine.UI", "Toggle"),
		*slider = u_class("UnityEngine.UI", "Slider"), *input = u_class("UnityEngine.UI", "InputField"),
		*text = u_class("UnityEngine.UI", "Text"), *selectable = u_class("UnityEngine.UI", "Selectable"),
		*tmpin = u_class("TMPro", "TMP_InputField"), *tmptext = u_class("TMPro", "TMP_Text");
	for (NSValue* v in comps) {
		Obj* c = v.pointerValue;
		if (!u_b(u_get(c, "isActiveAndEnabled"), YES)) continue;
		NSString *role = nil, *label = nil, *value = nil, *cls = nil;
		if (u_is(c, button)) { role = @"button"; label = child_text(c); cls = @"UnityEngine.UI.Button"; }
		else if (u_is(c, toggle)) { role = @"switch"; label = child_text(c); value = u_b(u_get(c, "isOn"), NO) ? @"1" : @"0"; cls = @"UnityEngine.UI.Toggle"; }
		else if (u_is(c, slider)) {
			role = @"adjustable";
			value = fmtf(u_f32(u_get(c, "value"), 0));
			cls = @"UnityEngine.UI.Slider";
		} else if (u_is(c, input) || u_is(c, tmpin)) {
			role = @"textfield";
			value = u_str(u_get(c, "text"));
			label = text_of(u_get(c, "placeholder"));
			cls = u_is(c, input) ? @"UnityEngine.UI.InputField" : @"TMPro.TMP_InputField";
		} else if (u_is(c, text) || u_is(c, tmptext)) {
			// a control's own caption / placeholder / text is that control's label or value
			void* a[] = { u_typeof(selectable) };
			if (selectable && u_call(c, "GetComponentInParent", 1, "System.Type", a, NULL)) continue;
			if (tmpin) {
				void* b[] = { u_typeof(tmpin) };
				if (u_call(c, "GetComponentInParent", 1, "System.Type", b, NULL)) continue;
			}
			role = @"text";
			label = text_of(c);
			if (!label) continue;
			cls = u_is(c, text) ? @"UnityEngine.UI.Text" : @"TMPro.TMP_Text";
		} else {
			continue;
		}
		if (!label && ![role isEqualToString:@"text"]) label = go_name(c);
		CGRect r = ui_rect(g, c);
		NSUInteger before = out.count;
		add(out, c, role, label, value, r, inst_key(c), cls);
		if (out.count == before) continue;
		NSMutableDictionary* d = out.lastObject;
		if (![role isEqualToString:@"text"] && !u_b(u_call(c, "IsInteractable", 0, NULL, NULL, NULL), YES)) d[@"enabled"] = @NO;
		if ([role isEqualToString:@"textfield"] && u_b(u_get(c, "isFocused"), NO)) d[@"focused"] = @YES;
		if ([role isEqualToString:@"adjustable"]) {
			d[@"min"] = @(u_f32(u_get(c, "minValue"), 0));
			d[@"max"] = @(u_f32(u_get(c, "maxValue"), 1));
		}
	}
}

// UI Toolkit: each UIDocument's tree of VisualElements
static BOOL named_like(Obj* o, const char* const* names, const char** which) {
	for (Klass* k = U.object_get_class(o); k; k = U.class_get_parent(k)) {
		const char* n = U.class_get_name ? U.class_get_name(k) : "";
		for (int i = 0; names[i]; i++)
			if (!strcmp(n, names[i])) { *which = names[i]; return YES; }
	}
	return NO;
}

typedef struct { float x, y; } UV2;
typedef struct { float x, y, w, h; } URect;

static void uitk_walk(Geo* g, Obj* ve, UV2 p0, UV2 k, NSString* path, NSMutableArray* out, int depth) {
	if (!ve || depth > 48 || out.count > 2000) return;
	if (!u_b(u_get(ve, "visible"), YES)) return;
	static const char* const kinds[] = { "Button", "Toggle", "Slider", "SliderInt", "TextField", "Label", NULL };
	const char* kind = NULL;
	if (named_like(ve, kinds, &kind)) {
		Obj* wb = u_get(ve, "worldBound");
		if (wb) {
			URect r = *(URect*)U.object_unbox(wb);
			// panel -> screen (top-left origin, pixels): the inverse of ScreenToPanel's linear map
			float sx0 = (r.x - p0.x) / k.x, sy0 = (r.y - p0.y) / k.y, sx1 = (r.x + r.w - p0.x) / k.x, sy1 = (r.y + r.h - p0.y) / k.y;
			double kx = g->view.width / g->sw, ky = g->view.height / g->sh;
			CGRect vr = CGRectMake(sx0 * kx, sy0 * ky, (sx1 - sx0) * kx, (sy1 - sy0) * ky);
			NSString *role = @"text", *label = nil, *value = nil;
			if (!strcmp(kind, "Button")) { role = @"button"; label = u_str(u_get(ve, "text")); }
			else if (!strcmp(kind, "Label")) label = u_str(u_get(ve, "text"));
			else {
				label = u_str(u_get(ve, "label"));
				Obj* val = u_get(ve, "value");
				if (!strcmp(kind, "Toggle")) { role = @"switch"; value = u_b(val, NO) ? @"1" : @"0"; }
				else if (!strcmp(kind, "TextField")) { role = @"textfield"; value = u_str(val); }
				else { role = @"adjustable"; value = !strcmp(kind, "SliderInt") ? [NSString stringWithFormat:@"%d", u_i32(val, 0)] : fmtf(u_f32(val, 0)); }
			}
			if (!label) label = u_str(u_get(ve, "name"));
			if (label || value) {
				add(out, ve, role, label, value, vr, [@"uitk:" stringByAppendingString:path], [NSString stringWithFormat:@"UnityEngine.UIElements.%s", kind]);
				if (!u_b(u_get(ve, "enabledInHierarchy"), YES) && out.count) ((NSMutableDictionary*)out.lastObject)[@"enabled"] = @NO;
			}
			return;   // a control's insides (its label, text input) are part of it
		}
	}
	int32_t n = u_i32(u_get(ve, "childCount"), 0);
	for (int32_t i = 0; i < n && i < 500; i++) {
		void* a[] = { &i };
		uitk_walk(g, u_call(ve, "ElementAt", 1, NULL, a, NULL), p0, k, [path stringByAppendingFormat:@".%d", i], out, depth + 1);
	}
}

static void uitk(Geo* g, NSArray* docs, NSMutableArray* out) {
	Klass* rpu = u_class("UnityEngine.UIElements", "RuntimePanelUtils");
	for (NSValue* v in docs) {
		Obj* doc = v.pointerValue;
		Obj* root = u_get(doc, "rootVisualElement");
		Obj* panel = u_get(root, "panel");
		if (!root || !panel) continue;
		// ScreenToPanel at two screen points gives the map (offset and scale) from screen pixels to the panel
		UV2 s0 = { 0, 0 }, s1 = { g->sw, g->sh };
		void* a0[] = { panel, &s0 };
		void* a1[] = { panel, &s1 };
		Obj* r0 = u_static(rpu, "ScreenToPanel", 2, NULL, a0);
		Obj* r1 = u_static(rpu, "ScreenToPanel", 2, NULL, a1);
		UV2 p0 = { 0, 0 }, k = { 1, 1 };
		if (r0 && r1) {
			p0 = *(UV2*)U.object_unbox(r0);
			UV2 p1 = *(UV2*)U.object_unbox(r1);
			if (p1.x != p0.x && p1.y != p0.y) k = (UV2){ (p1.x - p0.x) / g->sw, (p1.y - p0.y) / g->sh };
		}
		BOOL ok = NO;
		Obj* idb = u_call(doc, "GetInstanceID", 0, NULL, NULL, &ok);
		uitk_walk(g, root, p0, k, [NSString stringWithFormat:@"%d", ok ? u_i32(idb, 0) : 0], out, 0);
	}
}

// game objects with a renderer or a collider: their bounds projected with Camera.main
typedef struct { UV3 center, extents; } UBounds;

static void nodes(Geo* g, NSArray* comps, NSMutableArray* out) {
	Klass *renderer = u_class("UnityEngine", "Renderer"), *rect = u_class("UnityEngine", "RectTransform");
	if (!g->cam) return;
	NSMutableSet* seen = [NSMutableSet set];
	for (NSValue* v in comps) {
		Obj* c = v.pointerValue;
		if (u_is(c, renderer) && (!u_b(u_get(c, "enabled"), YES) || !u_b(u_get(c, "isVisible"), YES))) continue;
		if (!u_is(c, renderer) && !u_b(u_get(c, "enabled"), YES)) continue;
		Obj* go = u_get(c, "gameObject");
		if (!go || [seen containsObject:[NSValue valueWithPointer:go]]) continue;
		[seen addObject:[NSValue valueWithPointer:go]];
		if (!u_b(u_get(go, "activeInHierarchy"), YES)) continue;
		NSString* name = u_str(u_get(go, "name"));
		if (!name || (rect && u_is(u_get(go, "transform"), rect))) continue;   // UI is read above
		Obj* b = u_get(c, "bounds");
		if (!b) continue;
		UBounds bb = *(UBounds*)U.object_unbox(b);
		float x0 = INFINITY, y0 = INFINITY, x1 = -INFINITY, y1 = -INFINITY;
		int front = 0;
		for (int i = 0; i < 8; i++) {
			UV3 p = { bb.center.x + (i & 1 ? 1 : -1) * bb.extents.x, bb.center.y + (i & 2 ? 1 : -1) * bb.extents.y,
				bb.center.z + (i & 4 ? 1 : -1) * bb.extents.z };
			UV3 s;
			if (!world_to_screen(g->cam, p, &s) || s.z < 0) continue;   // behind the camera
			front++;
			x0 = MIN(x0, s.x); y0 = MIN(y0, s.y); x1 = MAX(x1, s.x); y1 = MAX(y1, s.y);
		}
		if (!front) continue;
		CGRect r = CGRectIntersection(px_to_view(g, x0, y0, x1, y1), CGRectMake(0, 0, g->view.width, g->view.height));
		add(out, go, @"node", name, nil, r, inst_key(go), @"UnityEngine.GameObject");
	}
}

static BOOL u_ready(void) {
	if (!u_init()) return NO;
	return u_class("UnityEngine", "Object") != NULL;
}

NSArray* simax_unity_elements(UIView* view) {
	if (!u_ready()) return nil;
	Geo g = { view.bounds.size };
	Klass* screen = u_class("UnityEngine", "Screen");
	g.sw = u_i32(u_static(screen, "get_width", 0, NULL, NULL), 0);
	g.sh = u_i32(u_static(screen, "get_height", 0, NULL, NULL), 0);
	if (g.sw <= 0 || g.sh <= 0) return nil;
	g.cam = u_static(u_class("UnityEngine", "Camera"), "get_main", 0, NULL, NULL);
	// the classes read (missing ones: that module is not in the build)
	const char* want[][2] = { { "UnityEngine.UI", "Selectable" }, { "UnityEngine.UI", "Text" }, { "TMPro", "TMP_Text" },
		{ "TMPro", "TMP_InputField" }, { "UnityEngine.UIElements", "UIDocument" }, { "UnityEngine", "Renderer" },
		{ "UnityEngine", "Collider" }, { "UnityEngine", "Collider2D" } };
	NSMutableArray* classes = [NSMutableArray array];
	for (size_t i = 0; i < sizeof(want) / sizeof(want[0]); i++) {
		Klass* k = u_class(want[i][0], want[i][1]);
		if (k) [classes addObject:[NSValue valueWithPointer:k]];
	}
	NSArray* comps = u_objects(classes);
	Klass *doc = u_class("UnityEngine.UIElements", "UIDocument"), *renderer = u_class("UnityEngine", "Renderer"),
		*col = u_class("UnityEngine", "Collider"), *col2 = u_class("UnityEngine", "Collider2D");
	NSMutableArray *ui = [NSMutableArray array], *docs = [NSMutableArray array], *world = [NSMutableArray array];
	NSMutableSet* dup = [NSMutableSet set];
	for (NSValue* v in comps) {
		if ([dup containsObject:v]) continue;   // a TMP_InputField is found as a Selectable and as itself
		[dup addObject:v];
		Obj* c = v.pointerValue;
		if (u_is(c, doc)) [docs addObject:v];
		else if (u_is(c, renderer) || u_is(c, col) || u_is(c, col2)) [world addObject:v];
		else [ui addObject:v];
	}
	NSMutableArray* out = [NSMutableArray array];
	@try {
		ugui(&g, ui, out);
		uitk(&g, docs, out);
		nodes(&g, world, out);
	} @catch (id ex) {
	}
	return out;
}

// ---------------------------------------------------------------------------------------------------------------------
// type

static void* u_field(Obj* o, const char* name) {
	if (!U.class_get_field_from_name || !U.field_get_value) return NULL;
	for (Klass* k = U.object_get_class(o); k; k = U.class_get_parent(k)) {
		void* f = U.class_get_field_from_name(k, name);
		if (!f) continue;
		void* v = NULL;
		U.field_get_value(o, f, &v);
		return v;
	}
	return NULL;
}

static Obj* u_mkstr(NSString* s) { return U.string_new(s.UTF8String ?: ""); }

NSDictionary* simax_unity_type(NSDictionary* req) {
	if (!objc_getClass("UnityView") || !u_ready()) return nil;
	NSString* t = req[@"text"] ?: @"";
	BOOL clear = [req[@"clear"] boolValue];
	// uGUI / TextMeshPro: the focused input field
	const char* fields[][2] = { { "UnityEngine.UI", "InputField" }, { "TMPro", "TMP_InputField" } };
	for (int i = 0; i < 2; i++) {
		Klass* k = u_class(fields[i][0], fields[i][1]);
		if (!k) continue;
		for (NSValue* v in u_objects(@[ [NSValue valueWithPointer:k] ])) {
			Obj* f = v.pointerValue;
			if (!u_b(u_get(f, "isFocused"), NO)) continue;
			NSString* old = clear ? @"" : (u_str(u_get(f, "text")) ?: @"");
			NSString* now = [old stringByAppendingString:t];
			void* a[] = { u_mkstr(now) };
			BOOL ok = NO;
			u_call(f, "set_text", 1, NULL, a, &ok);   // fires onValueChanged
			if (!ok) return @{ @"error": @"the Unity input field did not take the text" };
			// the on-screen keyboard's text: the field copies it back every frame while it is up
			Obj* kb = u_field(f, i == 0 ? "m_Keyboard" : "m_SoftKeyboard");
			if (kb) u_call(kb, "set_text", 1, NULL, a, NULL);
			Obj* ev = u_get(f, "onEndEdit");
			if (ev) u_call(ev, "Invoke", 1, NULL, a, NULL);
			return @{ @"typed": @(t.length), @"field": [NSString stringWithFormat:@"%s.%s", fields[i][0], fields[i][1]],
				@"value": u_str(u_get(f, "text")) ?: @"" };
		}
	}
	// UI Toolkit: the focused element of a document's panel, when it is a text field
	Klass* doc = u_class("UnityEngine.UIElements", "UIDocument");
	if (doc)
		for (NSValue* v in u_objects(@[ [NSValue valueWithPointer:doc] ])) {
			Obj* fe = u_get(u_get(u_get(u_get(v.pointerValue, "rootVisualElement"), "panel"), "focusController"), "focusedElement");
			static const char* const tf[] = { "TextField", NULL };
			const char* kind = NULL;
			if (!fe || !named_like(fe, tf, &kind)) continue;
			NSString* old = clear ? @"" : (u_str(u_get(fe, "value")) ?: @"");
			void* a[] = { u_mkstr([old stringByAppendingString:t]) };
			BOOL ok = NO;
			u_call(fe, "set_value", 1, NULL, a, &ok);   // a ChangeEvent, as typing sends
			if (!ok) return @{ @"error": @"the UI Toolkit text field did not take the text" };
			return @{ @"typed": @(t.length), @"field": @"UnityEngine.UIElements.TextField", @"value": u_str(u_get(fe, "value")) ?: @"" };
		}
	return nil;
}
