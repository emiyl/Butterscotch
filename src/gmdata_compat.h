#ifndef _BS_GMDATA_COMPAT_H_
#define _BS_GMDATA_COMPAT_H_

#define DataWin gmdata_DataWin
#define DataWin_initParserOptions gmdata_DataWin_initParserOptions
#define DataWin_applyParserOptions gmdata_DataWin_applyParserOptions
#define DataWin_loadFile gmdata_DataWin_loadFile
#define DataWin_parseWithOptions gmdata_DataWin_parseWithOptions
#define DataWin_parse gmdata_DataWin_parse
#define DataWin_free gmdata_DataWin_free
#define DataWin_detectVersionFromFile gmdata_DataWin_detectVersionFromFile
#define DataWin_isVersionAtLeast gmdata_DataWin_isVersionAtLeast
#define DataWin_bumpVersionTo gmdata_DataWin_bumpVersionTo
#define DataWinParserOptions gmdata_DataWinParserOptions
#define DataWinLoadType gmdata_DataWinLoadType
#define DATAWINLOADTYPE_LOAD_PER_CHUNK gmdata_DATAWINLOADTYPE_LOAD_PER_CHUNK
#define DATAWINLOADTYPE_LOAD_IN_MEMORY_AHEAD_OF_TIME gmdata_DATAWINLOADTYPE_LOAD_IN_MEMORY_AHEAD_OF_TIME
#define DATAWINLOADTYPE_MAP_FILE gmdata_DATAWINLOADTYPE_MAP_FILE
#define StringBooleanEntry gmdata_StringBooleanEntry
#define Gen8 gmdata_Gen8
#define Optn gmdata_Optn
#define OptnConstant gmdata_OptnConstant
#define Language gmdata_Language
#define Lang gmdata_Lang
#define ExtensionFunction gmdata_ExtensionFunction
#define ExtensionFile gmdata_ExtensionFile
#define Extension gmdata_Extension
#define Extn gmdata_Extn
#define AudioEntryFlags gmdata_AudioEntryFlags
#define AUDIO_ENTRY_FLAG_IS_EMBEDDED gmdata_AUDIO_ENTRY_FLAG_IS_EMBEDDED
#define AUDIO_ENTRY_FLAG_IS_COMPRESSED gmdata_AUDIO_ENTRY_FLAG_IS_COMPRESSED
#define AUDIO_ENTRY_FLAG_IS_DECOMPRESSED_ON_LOAD gmdata_AUDIO_ENTRY_FLAG_IS_DECOMPRESSED_ON_LOAD
#define AUDIO_ENTRY_FLAG_REGULAR gmdata_AUDIO_ENTRY_FLAG_REGULAR
#define Sound gmdata_Sound
#define Sond gmdata_Sond
#define AudioGroup gmdata_AudioGroup
#define Agrp gmdata_Agrp
#define Sprite gmdata_Sprite
#define Sprt gmdata_Sprt
#define Background gmdata_Background
#define Bgnd gmdata_Bgnd
#define RoomBackground gmdata_RoomBackground
#define RoomView gmdata_RoomView
#define RoomGameObject gmdata_RoomGameObject
#define RoomTile gmdata_RoomTile
#define SpriteInstance gmdata_SpriteInstance
#define RoomLayerAssetsData gmdata_RoomLayerAssetsData
#define RoomLayerBackgroundData gmdata_RoomLayerBackgroundData
#define RoomLayerInstancesData gmdata_RoomLayerInstancesData
#define RoomLayerTilesData gmdata_RoomLayerTilesData
#define RoomLayer gmdata_RoomLayer
#define Room gmdata_Room
#define RoomChunk gmdata_RoomChunk
#define GamePath gmdata_GamePath
#define PathPoint gmdata_PathPoint
#define InternalPathPoint gmdata_InternalPathPoint
#define PathPositionResult gmdata_PathPositionResult
#define PathChunk gmdata_PathChunk
#define Script gmdata_Script
#define Scpt gmdata_Scpt
#define Glob gmdata_Glob
#define Shader gmdata_Shader
#define Shdr gmdata_Shdr
#define KerningPair gmdata_KerningPair
#define FontGlyph gmdata_FontGlyph
#define Font gmdata_Font
#define FontChunk gmdata_FontChunk
#define EventAction gmdata_EventAction
#define TimelineMoment gmdata_TimelineMoment
#define Timeline gmdata_Timeline
#define Tmln gmdata_Tmln
#define ObjectEvent gmdata_ObjectEvent
#define ObjectEventList gmdata_ObjectEventList
#define PhysicsVertex gmdata_PhysicsVertex
#define GameObject gmdata_GameObject
#define Objt gmdata_Objt
#define RoomLayerType gmdata_RoomLayerType
#define RoomLayerType_Path gmdata_RoomLayerType_Path
#define RoomLayerType_Background gmdata_RoomLayerType_Background
#define RoomLayerType_Instances gmdata_RoomLayerType_Instances
#define RoomLayerType_Assets gmdata_RoomLayerType_Assets
#define RoomLayerType_Tiles gmdata_RoomLayerType_Tiles
#define RoomLayerType_Effect gmdata_RoomLayerType_Effect
#define RoomLayerType_Path2 gmdata_RoomLayerType_Path2
#define TexturePageItem gmdata_TexturePageItem
#define Tpag gmdata_Tpag
#define Variable gmdata_Variable
#define Vari gmdata_Vari
#define LocalVar gmdata_LocalVar
#define CodeLocals gmdata_CodeLocals
#define Function gmdata_Function
#define Func gmdata_Func
#define AnimCurvePoint gmdata_AnimCurvePoint
#define AnimCurveChannel gmdata_AnimCurveChannel
#define AnimCurve gmdata_AnimCurve
#define Acrv gmdata_Acrv
#define TextureGroupInfo gmdata_TextureGroupInfo
#define Tgin gmdata_Tgin
#define Texture gmdata_Texture
#define Txtr gmdata_Txtr
#define AudioEntry gmdata_AudioEntry
#define Audo gmdata_Audo
#define CodeEntry gmdata_CodeEntry
#define Code gmdata_Code
#define DetectedFormat gmdata_DetectedFormat
#define FilterEffect gmdata_FilterEffect
#define Feds gmdata_Feds
#define Feat gmdata_Feat
#define SequencePlaybackType gmdata_SequencePlaybackType
#define SequenceChannel gmdata_SequenceChannel
#define SequenceTrack gmdata_SequenceTrack
#define SequenceKeyframe gmdata_SequenceKeyframe
#define SequenceFunctionIdEntry gmdata_SequenceFunctionIdEntry
#define Sequence gmdata_Sequence
#define Seqn gmdata_Seqn
#define AssetTagEntry gmdata_AssetTagEntry
#define Tags gmdata_Tags
#define EmbiItem gmdata_EmbiItem
#define Embi gmdata_Embi
#define ParticleEmitter gmdata_ParticleEmitter
#define Psem gmdata_Psem
#define ParticleSystem gmdata_ParticleSystem
#define Psys gmdata_Psys
#define Gmen gmdata_Gmen
#define Dafl gmdata_Dafl
#define Uilr gmdata_Uilr
#define StatEventField gmdata_StatEventField
#define StatEvent gmdata_StatEvent
#define Stat gmdata_Stat

#include "gmdata.h"

#undef DataWin
#undef DataWin_initParserOptions
#undef DataWin_applyParserOptions
#undef DataWin_loadFile
#undef DataWin_parseWithOptions
#undef DataWin_parse
#undef DataWin_free
#undef DataWin_detectVersionFromFile
#undef DataWin_isVersionAtLeast
#undef DataWin_bumpVersionTo
#undef DataWinParserOptions
#undef DataWinLoadType
#undef DATAWINLOADTYPE_LOAD_PER_CHUNK
#undef DATAWINLOADTYPE_LOAD_IN_MEMORY_AHEAD_OF_TIME
#undef DATAWINLOADTYPE_MAP_FILE
#undef StringBooleanEntry
#undef Gen8
#undef Optn
#undef OptnConstant
#undef Language
#undef Lang
#undef ExtensionFunction
#undef ExtensionFile
#undef Extension
#undef Extn
#undef AudioEntryFlags
#undef AUDIO_ENTRY_FLAG_IS_EMBEDDED
#undef AUDIO_ENTRY_FLAG_IS_COMPRESSED
#undef AUDIO_ENTRY_FLAG_IS_DECOMPRESSED_ON_LOAD
#undef AUDIO_ENTRY_FLAG_REGULAR
#undef Sound
#undef Sond
#undef AudioGroup
#undef Agrp
#undef Sprite
#undef Sprt
#undef Background
#undef Bgnd
#undef RoomBackground
#undef RoomView
#undef RoomGameObject
#undef RoomTile
#undef SpriteInstance
#undef RoomLayerAssetsData
#undef RoomLayerBackgroundData
#undef RoomLayerInstancesData
#undef RoomLayerTilesData
#undef RoomLayer
#undef Room
#undef RoomChunk
#undef GamePath
#undef PathPoint
#undef InternalPathPoint
#undef PathPositionResult
#undef PathChunk
#undef Script
#undef Scpt
#undef Glob
#undef Shader
#undef Shdr
#undef KerningPair
#undef FontGlyph
#undef Font
#undef FontChunk
#undef EventAction
#undef TimelineMoment
#undef Timeline
#undef Tmln
#undef ObjectEvent
#undef ObjectEventList
#undef PhysicsVertex
#undef GameObject
#undef Objt
#undef RoomLayerType
#undef RoomLayerType_Path
#undef RoomLayerType_Background
#undef RoomLayerType_Instances
#undef RoomLayerType_Assets
#undef RoomLayerType_Tiles
#undef RoomLayerType_Effect
#undef RoomLayerType_Path2
#undef TexturePageItem
#undef Tpag
#undef Variable
#undef Vari
#undef LocalVar
#undef CodeLocals
#undef Function
#undef Func
#undef AnimCurvePoint
#undef AnimCurveChannel
#undef AnimCurve
#undef Acrv
#undef TextureGroupInfo
#undef Tgin
#undef Texture
#undef Txtr
#undef AudioEntry
#undef Audo
#undef CodeEntry
#undef Code
#undef DetectedFormat
#undef FilterEffect
#undef Feds
#undef Feat
#undef SequencePlaybackType
#undef SequenceChannel
#undef SequenceTrack
#undef SequenceKeyframe
#undef SequenceFunctionIdEntry
#undef Sequence
#undef Seqn
#undef AssetTagEntry
#undef Tags
#undef EmbiItem
#undef Embi
#undef ParticleEmitter
#undef Psem
#undef ParticleSystem
#undef Psys
#undef Gmen
#undef Dafl
#undef Uilr
#undef StatEventField
#undef StatEvent
#undef Stat

#endif
