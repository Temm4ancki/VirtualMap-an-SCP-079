const int MAX_POSSIBLE_CATEGORIES = 32;

enum Roles
{
	ROLE_SCP_079,
};

namespace Roles
{
	void Initialize()
	{
		Role@ scp079 = Role(ROLE_SCP_079, "SCP-079", CATEGORY_ANOMALY, PlayerModel(CLASS_D_MODEL), Color(200, 0, 0), "Наблюдай за комплексом. Используй карту (M). Помогай или мешай выжившим. Жди 45 секунд чтобы двигаться.",
		{
			Spawnpoint(vector3(140.2, -10894.2, 1558.2), 0.0, 0.0, world.GetRoomByIdentifier(r_cont1_079))
		}, {}, true, 0.0, 1000, 0.0, true);
		
		Add(scp079);	
	}
}