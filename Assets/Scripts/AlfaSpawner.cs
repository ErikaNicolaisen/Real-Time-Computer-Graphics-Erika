using UnityEngine;

// Spawns a grid of Alfa copies so we can measure batching performance.
public class AlfaSpawner : MonoBehaviour
{
    public GameObject prefab;
    public int countX = 15, countZ = 15;   // 15 x 15 = 225 Alfas
    public float spacing = 0.4f;

    void Start()
    {
        for (int x = 0; x < countX; x++)
            for (int z = 0; z < countZ; z++)
                Instantiate(prefab,
                    transform.position + new Vector3(x * spacing, 0, z * spacing),
                    Quaternion.Euler(0, Random.Range(0f, 360f), 0),
                    transform);
    }
}